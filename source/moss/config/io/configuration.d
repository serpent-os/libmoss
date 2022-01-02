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
import std.traits : getUDAs, isArray;
import moss.config.io.schema;
import std.range : empty;
import std.file : dirEntries, DirEntry, exists, isDir, isFile, SpanMode;
import std.array : array;
import std.algorithm : filter, each;

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
 */
public final class Configuration(C)
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
                    .each!((e) => loadConfigFile(e.name));
            }
            else if ((path.type & ConfigType.File) == ConfigType.File && searchPath.isFile)
            {
                /* Handle a specific file (.conf) */
                loadConfigFile(searchPath);
            }
        }
    }

private:

    /**
     * Attempt to load a Snippet for the given input path
     */
    void loadConfigFile(in string path)
    {
        auto snippet = new Snippet!ConfType();
        snippet.load(path);
        _snippets ~= snippet;
    }

    alias ConfType = C;
    static enum arrayConfig = isArray!ConfType;

    static if (arrayConfig)
    {
        alias ElemType = typeof(*ConfType.init.ptr);

    }
    else
    {
        alias ElemType = ConfType;
    }

    SearchPath[] paths;
    Snippet!(ConfType)[] _snippets;

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
        writeln(s.config);
    }
}
