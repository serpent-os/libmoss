/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.path_definition
 *
 * Defines various types of paths.
 *
 * Currently supports "any", "exe", "symlink" and "special".
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.path_definition;

import std.conv : to;
import std.exception : enforce;
import std.experimental.logger;
import std.format : format;
import std.string : strip;

struct PathDefinition
{
    /**
     * Constructor with default type (PathType.any)
     */
    this(string p, string t = "any")
    {
        enforce(t.strip in ptStringLookup,
                format!"PathDefinition(path, type): illegal type <%s>. Allowed type is any of %s"(t.strip,
                    ptStringLookup.keys));
        enforce(p.strip.length != 0, format!"PathDefinition(path, type): path cannot be empty");
        this.path = p;
        this.type = ptStringLookup[t];
    }

    /**
     * Properly formatted path
     */
    string toString() @safe const
    {
        ///TODO: Decide how to handle this
        return format!"%s : %s"(this.path, strPathTypeLookup[this.type]);
    }

    /**
     * Make it possible to test PathDefinitions for equality
     */
    bool opEquals()(auto ref const PathDefinition rhs) @trusted const
    {
        return this.type == rhs.type && this.path == rhs.path;
    }

    /**
     * Compare two PathDefinitions
     */
    int opCmp()(auto ref const PathDefinition rhs) @trusted const
    {
        if (this.path < rhs.path)
        {
            return -1;
        }
        else if (this.path > rhs.path)
        {
            return 1;
        }
        if (this.type < rhs.type)
        {
            return -1;
        }
        else if (this.type > rhs.type)
        {
            return 1;
        }
        return 0;
    }

    /**
     * Return an ulong hash of a PathDefinition
     */
    ulong toHash() @trusted const
    {
        import std.conv : to;
        import std.digest : toHexString;
        import xxhash;

        auto hashFunc = new XXH3_64;
        auto sourceBytes = cast(ubyte[]) this.toString;
        hashFunc.put(sourceBytes);
        /* hashFunc.finish returns an 8-byte (64bit) long ubyte[] when using XXH3_64 */
        auto hash = hashFunc.finish.toHexString.to!ulong;
        return hash;
    }

    /**
     * Path to match
     */
    string path;

    /**
     * Path type to match.
     */
    PathType type;

    /**
     * Supported path types.
     */
    static enum PathType : ubyte
    {
        any = 0,
        exe,
        symlink,
        special
    }

    /**
     * Ensure that it's easy to convert a string to a PathType
     */
    private static immutable PathType[string] ptStringLookup;
    private static immutable string[PathType] strPathTypeLookup;

    /**
     * Ensure that a single instance each of ptStringLookup and strPathTypeLookup is shared between struct instances
     */
    shared static this()
    {
        /* forward lookup table */
        ptStringLookup = [
            "any": PathType.any,
            "exe": PathType.exe,
            "symlink": PathType.symlink,
            "special": PathType.special
        ];
        /* reverse lookup table */
        strPathTypeLookup = [
            PathType.any: "any",
            PathType.exe: "exe",
            PathType.symlink: "symlink",
            PathType.special: "special"
        ];
    }
}
