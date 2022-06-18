/* SPDX-License-Identifier: Zlib */

/**
 * Util
 *
 * Various moss core utilit functions
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
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
 * Attempt construction of a hardlink.
 */
pragma(inline, true) void hardLink(const(string) sourcePath, const(string) destPath) @trusted
{
    auto sourceZ = sourcePath.toStringz;
    auto targetZ = destPath.toStringz;

    auto ret = link(sourceZ, targetZ);
    auto err = strerror(errno);
    enforce(ret == 0, format!"hardLink(): Failed to link %s to %s: %s"(sourcePath,
            destPath, err !is null ? fromStringz(err) : ""));
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
    const auto expHash = "5eca857080b9a65301edc2c6ebb5ebd3abc5ed679c49ab532a300c91d3674fc8";

    immutable auto directHash = computeSHA256("LICENSE");
    immutable auto mapHash = computeSHA256("LICENSE", true);

    assert(expHash == directHash, "Mismatch in direct hash");
    assert(expHash == directHash, "Mismatch in mmap hash");
}
