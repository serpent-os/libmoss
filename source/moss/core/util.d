/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.util
 *
 * Various moss core utility functions.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.core.util;

import core.sys.posix.unistd;
import core.stdc.string;
import core.stdc.errno;
import std.exception : enforce;
import std.string : format, fromStringz, toStringz;
import std.range : chunks;
import std.digest : makeDigest;
import std.stdio : File;
import std.digest.sha : SHA256, toHexString;
import std.string : toLower;
import std.mmfile;
import std.algorithm : each;
import moss.core : ChunkSize;

/**
 * Returns true if the path exists and is writable
 */
pragma(inline, true) bool checkWritable(const(string) path) @trusted
{
    return access(path.toStringz, W_OK) == 0;
}

/**
 * Compute SHA256sum for the given input path, optionally using mmap
 */
string computeSHA256(in string path, bool useMmap = false)
{
    auto sha = makeDigest!SHA256();
    auto inp = File(path, "rb");
    MmFile mapped = null;
    ubyte[] dataMap;

    scope (exit)
    {
        inp.close();
    }

    if (!useMmap)
    {
        inp.byChunk(ChunkSize).each!((b) => sha.put(b));
    }
    else
    {
        mapped = new MmFile(inp);
        dataMap = cast(ubyte[]) mapped[0 .. mapped.length];
        dataMap.chunks(ChunkSize).each!((b) => sha.put(b));
    }

    return toHexString(sha.finish()).toLower();
}

/**
 * Outperforms buildPath considerably by
 * not attempting to fold or normalize the paths
 *
 * Given our requirements we assume this *will not* throw,
 * otherwise we'll runtime panic.
 *
 * Note: This will not fold slashes contained in follow up elements
 *
 * Params:
 *      datum   = Elements to join
 * Returns: newly allocated string joining all path elements by "/"
 */
pragma(inline, true) pure auto joinPath(S...)(in S datum) @safe nothrow
{
    import std.array : join;
    import std.exception : assumeWontThrow;

    static assert(S.length > 0, "joinPath() requires at least one element");
    static immutable dchar[] joinStr = "/";
    return assumeWontThrow(join([datum[0 .. $]], joinStr));
}

unittest
{
    const auto expHash = "5eca857080b9a65301edc2c6ebb5ebd3abc5ed679c49ab532a300c91d3674fc8";

    immutable auto directHash = computeSHA256("LICENSE");
    immutable auto mapHash = computeSHA256("LICENSE", true);

    assert(expHash == directHash, "Mismatch in direct hash");
    assert(expHash == directHash, "Mismatch in mmap hash");
}
