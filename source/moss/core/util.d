/*
 * This file is part of moss-core.
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

module moss.core.util;

import core.sys.posix.unistd;
import core.stdc.string;
import core.stdc.errno;
import std.exception : enforce;
import std.string : format, toStringz;
import std.range : chunks;
import std.digest : makeDigest;
import std.stdio : File;
import std.digest.sha : SHA256, toHexString;
import std.string : toLower;
import std.mmfile;
import std.algorithm : each;
import moss.core : ChunkSize;

/**
 * Attempt construction of a hardlink.
 */
pragma(inline, true) void hardLink(const(string) sourcePath, const(string) destPath) @trusted
{
    auto sourceZ = sourcePath.toStringz;
    auto targetZ = destPath.toStringz;

    auto ret = link(sourceZ, targetZ);
    auto err = strerror(errno);
    enforce(ret == 0, "hardLink(): Failed to link %s to %s: %s".format(sourcePath,
            destPath, err !is null ? err[0 .. strlen(err)] : ""));
}

/**
 * Attempt hardlink, if it fails, fallback to a copy
 */
pragma(inline, true) void hardLinkOrCopy(const(string) sourcePath, const(string) destPath) @trusted
{
    try
    {
        hardLink(sourcePath, destPath);
        return;
    }
    catch (Exception ex)
    {
    }

    import std.file : copy;

    copy(sourcePath, destPath);
}

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

unittest
{
    const auto expHash = "6aad886e25795d06dfe468782caac1d4991a9b4fca7f003d754d0b326abb43dc";

    immutable auto directHash = computeSHA256("LICENSE");
    immutable auto mapHash = computeSHA256("LICENSE", true);

    assert(expHash == directHash, "Mismatch in direct hash");
    assert(expHash == directHash, "Mismatch in mmap hash");
}
