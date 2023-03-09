/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.config.io.configuration
 *
 * Support for layered moss configuration snippets
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.config.io.configuration;

import moss.config.io.snippet;

import moss.config.io.schema;
import std.algorithm : find, filter, each, map, uniq, sort, joiner;
import std.array : array, join;
import std.exception : enforce;
import std.file : dirEntries, DirEntry, exists, isDir, readLink, isSymlink, isFile, SpanMode;
import std.range : chain, empty;
import std.string : format, endsWith;
import std.traits : getUDAs, isArray, FieldNameTuple;

/**
 * If a symlink points to /dev/null - it's "masked"
 */
private static immutable(string) maskTarget = "/dev/null";

private enum ConfigType
{
    /**
     * Expect a file
     */
    File = 1 << 0,

    /**
     * Expect a directory
     */
    Directory = 1 << 1,

    /**
     * Expect a vendor config
     */
    Vendor = 1 << 2,

    /**
     * Expect as admin type
     */
    Admin = 1 << 3,
}

private struct SearchPath
{
    string path;
    ConfigType type;
}

/**
 * configSuffix is set per file (snippet)
 */
public static immutable(string) configSuffix = ".conf";

/**
 * configDir is added to domain to compute configuration directories
 */
public static immutable(string) configDir = ".conf.d";

/**
 * Required directories that form the basis of a Configuration
 */
package enum Directories : string
{
    Vendor = "share",
    Admin = "etc"
}

/**
 * The Configuration is merged from multiple snippet sources which can be
 * individually enabled/masked/etc
 *
 * It is up to subclasses to do something *useful* with this management
 */
public class Configuration(C)
{
    /**
     * Construct a new Configuration
     */
    this(string vendorPrefix = "usr")
    {
        enum udas = getUDAs!(ElemType, ConfigurationDomain);
        static assert(udas.length == 1,
                "Configuration!" ~ C.stringof ~ ": No domain set via @ConfigurationDomain");
        static assert(!udas[0].domain.empty, "Configuration!" ~ C.stringof ~ ": Domain is empty");
        static assert(!udas[0].applicationIdentity.empty,
                "Configuration!" ~ C.stringof ~ "ApplicationID is empty");
        _domain = udas[0];

        _paths = [
            /* Vendor possible paths */
            SearchPath(format!"%s/%s/%s/%s%s"(vendorPrefix, cast(string) Directories.Vendor,
                    domain.applicationIdentity, domain.domain, configSuffix),
                    ConfigType.File | ConfigType.Vendor),
            SearchPath(format!"%s/%s/%s/%s%s"(vendorPrefix, cast(string) Directories.Vendor,
                    domain.applicationIdentity, domain.domain, configDir),
                    ConfigType.Directory | ConfigType.Vendor),

            /* Admin possible paths */
            SearchPath(format!"%s/%s/%s%s"(cast(string) Directories.Admin,
                    domain.applicationIdentity, domain.domain, configSuffix),
                    ConfigType.File | ConfigType.Vendor),
            SearchPath(format!"%s/%s/%s%s"(cast(string) Directories.Admin,
                    domain.applicationIdentity, domain.domain, configDir),
                    ConfigType.Directory | ConfigType.Admin),
        ];
    }

    /**
     * Return the active SearchPath[] for this configuration
     */
    pragma(inline, true) pure @property const(SearchPath[]) paths() @safe @nogc nothrow
    {
        return _paths;
    }

    /**
     * Return the domain for this configuration (i.e. "repos")
     */
    pragma(inline, true) pure @property const(ConfigurationDomain) domain() @safe @nogc nothrow
    {
        return _domain;
    }

    /**
     * Load from the specific system paths within the given rootDirectory
     */
    void load(in string rootDirectory)
    {
        /**
         * Placeholder; Eventually handle masking logic based on Vendor vs Admin path
         */
        void configLoader(in string path, in ConfigType type)
        {
            loadConfigFile(path, type);
        }

        /* Iterate potential search paths */
        foreach (path; _paths)
        {
            /* Build path and ensure it is usable */
            immutable auto searchPath = join([rootDirectory, path.path], "/");
            if (!searchPath.exists)
            {
                continue;
            }

            if ((path.type & ConfigType.Directory) == ConfigType.Directory && searchPath.isDir)
            {
                /* Find .conf files within .conf.d according to alpha sort */
                string[] entries = dirEntries(searchPath, SpanMode.shallow, false).map!(
                        (e) => cast(string) e.name.dup)
                    .filter!((n) => n.endsWith(configSuffix) && !n.isDir)
                    .array;
                entries.sort!((a, b) => a < b);
                entries.each!((n) => configLoader(n, path.type));
            }
            else if ((path.type & ConfigType.File) == ConfigType.File && searchPath.isFile)
            {
                /* Handle a specific file (.conf) */
                loadConfigFile(searchPath, path.type);
            }
        }

        /* If all has been loaded now, we can load all *valid* sections */
        static if (arrayConfig)
        {
            loadSections();
        }
        else
        {
            loadConfiguration();
        }
    }

    /**
     * Return all active snippets in their original order
     */
    pure auto @property snippets() @safe @nogc nothrow const
    {
        return _snippets.filter!((ref s) => s.enabled);
    }

    static if (arrayConfig)
    {

        /**
         * Extract unique IDs across all snippets
         */
        auto @property ids() const
        {
            string[] allIds = _snippets.filter!((s) => s.enabled)
                .map!((s) => s.ids.map!((i) => cast(string) i))
                .joiner
                .array;
            allIds.sort();
            return allIds.uniq;
        }

        /**
         * Return all known sections
         */
        pure auto @property sections() @safe nothrow
        {
            return _sections.values;
        }
    }
    else
    {

        /**
         * For a flat configuration style, return the root configuration
         * object.
         */
        pure @property auto config() @trusted @nogc nothrow const
        {
            return _config;
        }
    }

private:

    /**
     * Attempt to load a Snippet for the given input path
     */
    void loadConfigFile(in string path, ConfigType type)
    {
        auto snippet = new SnippetType(path);
        bool masked = false;

        if ((type & ConfigType.Admin) == ConfigType.Admin)
        {
            adminSnippets ~= snippet;
            immutable auto name = snippet.name;

            if (isMasked(path))
            {
                vendorSnippets.find!((s) => s.name == name)
                    .each!((s) => s.enabled = false);
                return;
            }
        }
        else if ((type & ConfigType.Vendor) == ConfigType.Vendor)
        {
            vendorSnippets ~= snippet;
        }

        snippet.load();
        _snippets ~= snippet;
    }

    alias ConfType = C;
    alias SnippetType = Snippet!ConfType;
    static enum arrayConfig = isArray!ConfType;

    /**
     * Ascertain the configuration type (dynamic array etc)
     */
    static if (arrayConfig)
    {
        alias ElemType = typeof(*ConfType.init.ptr);

        /* We contain sections as its a list of types with an identifier */
        ElemType[string] _sections;

        /**
         * Handle the global sections based on identifiers within the snippet
         */
        void loadSnippetSections(ref SnippetType snip)
        {
            foreach (ref candidateSection; snip.config)
            {
                const auto id = candidateSection.id;
                ElemType* storedSection = null;

                /* Store the new section if it doesn't exist */
                if (!(id in _sections))
                {
                    _sections[id] = ElemType.init;
                    storedSection = &_sections[id];
                    storedSection.id = id;
                }
                else
                {
                    storedSection = &_sections[id];
                }

                /* For every explicitly defined field, override current value */
                static foreach (idx, name; FieldNameTuple!ElemType)
                {
                    {
                        /* Get candidate value */
                        mixin("auto candidateFieldValue = candidateSection." ~ name ~ ";");

                        if (snip.explicitlyDefined(name, id))
                        {
                            mixin("storedSection." ~ name ~ " = candidateFieldValue;");
                        }
                    }
                }
            }
        }

        /**
         * Run through all *enabled* snippets to build the final sections for the
         * configuration
         */
        void loadSections()
        {
            chain(vendorSnippets.filter!((s) => s.enabled), adminSnippets.filter!((s => s.enabled))).each!(
                    (s) => loadSnippetSections(s));
        }

    }
    else
    {
        /* Flat configuration format, no sections at all */
        alias ElemType = ConfType;

        ElemType _config = ElemType.init;

        /**
         * Handle potential overrides of fields within each encountered object.
         */
        void loadSnippetConfiguration(ref SnippetType snip)
        {
            static foreach (idx, name; FieldNameTuple!ElemType)
            {
                {
                    /* Get candidate value */
                    mixin("auto candidateFieldValue = snip.config." ~ name ~ ";");
                    if (snip.explicitlyDefined(name))
                    {
                        /* TODO: Support nested structs */
                        mixin("_config." ~ name ~ " = candidateFieldValue;");
                    }
                }
            }
        }

        /**
         * Run through all *enabled* snippets to build the final configuration object
         */
        void loadConfiguration()
        {
            chain(vendorSnippets.filter!((s) => s.enabled), adminSnippets.filter!((s => s.enabled))).each!(
                    (s) => loadSnippetConfiguration(s));
        }
    }

    /**
     * A path is masked if it points to /dev/null
     */
    static bool isMasked(in string path) @system
    {
        if (!path.isSymlink)
        {
            return false;
        }
        auto target = path.readLink();
        return target == maskTarget;
    }

    SearchPath[] _paths;
    SnippetType[] _snippets;

    /* Separation of snippet types */
    SnippetType[] adminSnippets;
    SnippetType[] vendorSnippets;

    ConfigurationDomain _domain;
}
