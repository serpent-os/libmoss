/*
 * This file is part of moss-config.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.config.io.configuration;

import moss.config.io.snippet;

import std.path : buildPath;
import std.exception : enforce;
import std.string : format, endsWith;
import std.traits : getUDAs, isArray, FieldNameTuple;
import moss.config.io.schema;
import std.range : chain, empty;
import std.file : dirEntries, DirEntry, exists, isDir, readLink, isSymlink, isFile, SpanMode;
import std.array : array;
import std.algorithm : find, filter, each, map, uniq, sort, joiner;

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
    Vendor = buildPath("usr", "share", "moss"),
    Admin = buildPath("etc", "moss")
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
    this()
    {
        enum udas = getUDAs!(ElemType, DomainKey);
        static assert(udas.length == 1,
                "Configuration!" ~ C.stringof ~ ": No domain set via @DomainKey");
        static assert(!udas[0].key.empty, "Configuration!" ~ C.stringof ~ ": Domain is empty");
        _domain = udas[0].key;

        paths = [
            /* Vendor possible paths */
            SearchPath(format!"%s/%s%s"(cast(string) Directories.Vendor, domain,
                    configSuffix), ConfigType.File | ConfigType.Vendor),
            SearchPath(format!"%s/%s%s"(cast(string) Directories.Vendor, domain,
                    configDir), ConfigType.Directory | ConfigType.Vendor),

            /* Admin possible paths */
            SearchPath(format!"%s/%s%s"(cast(string) Directories.Admin, domain,
                    configSuffix), ConfigType.File | ConfigType.Vendor),
            SearchPath(format!"%s/%s%s"(cast(string) Directories.Admin,
                    domain, configDir), ConfigType.Directory | ConfigType.Admin),
        ];
    }

    /**
     * Return the domain for this configuration (i.e. "repos")
     */
    pragma(inline, true) pure @property const(string) domain() @safe @nogc nothrow
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
        foreach (path; paths)
        {
            /* Build path and ensure it is usable */
            immutable auto searchPath = rootDirectory.buildPath(path.path);
            if (!searchPath.exists)
            {
                continue;
            }

            if ((path.type & ConfigType.Directory) == ConfigType.Directory && searchPath.isDir)
            {
                /* Find .conf files within .conf.d */
                dirEntries(searchPath, SpanMode.shallow, false).array
                    .filter!((DirEntry e) => e.name.endsWith(configSuffix) && !e.name.isDir)
                    .each!((e) => configLoader(e.name, path.type));
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
        alias ElemType = ConfType;
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

    SearchPath[] paths;
    SnippetType[] _snippets;

    /* Separation of snippet types */
    SnippetType[] adminSnippets;
    SnippetType[] vendorSnippets;

    string _domain = null;
}

private unittest
{
    import moss.config.repo;
    import std.stdio : writeln;

    auto n = new Configuration!(Repository[])();
    writeln(n.paths);
    n.load("test/");
    writeln("NSNIPPETS: ", n._snippets.length);

    foreach (s; n._snippets)
    {
        writeln("enabled? ", s.enabled, "  ", s.config);
    }

    writeln(n.sections);
}
