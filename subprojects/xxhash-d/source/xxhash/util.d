/*
 * This file is part of xxhash-d.
 *
 * Copyright © 2021 Serpent OS Developers
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

module xxhash.util;

import std.stdio : File;
import std.mmfile : MmFile;
import std.algorithm : each;
import std.range : chunks;
import std.digest : toHexString, LetterCase;

public import xxhash : XXH3, XXH3_64, XXH3_128;

public ubyte[N / 8] computeXXH3(uint N)(XXH3!N helper, in string path,
        uint chunkSize, bool useMmap = false)
{
    auto inp = File(path, "rb");
    MmFile mapped = null;
    ubyte[] dataMap;

    scope (exit)
    {
        inp.close();
    }

    if (!useMmap)
    {
        inp.byChunk(chunkSize).each!((b) => helper.put(b));
    }
    else
    {
        mapped = new MmFile(inp);
        dataMap = cast(ubyte[]) mapped[0 .. mapped.length];
        dataMap.chunks(chunkSize).each!((b) => helper.put(b));
    }

    return helper.finish();
}
/**
 * Factory function to compute an xxh3 checksum for the given path, optionally
 * using mmap (ideal for files larger than 16kib) and a specific chunk size. We
 * recommend using a 4mib (1024 * 1024 * 4) chunksize here.
 */
public char[(N / 8) * 2] computeXXH3_hexdigest(uint N)(XXH3!N helper,
        in string path, uint chunkSize, bool useMmap = false)
{
    return toHexString!(LetterCase.lower)(computeXXH3!N(helper, path, chunkSize, useMmap));
}

public alias computeXXH3_64 = computeXXH3!64;
public alias computeXXH3_128 = computeXXH3!128;
public alias computeXXH3_hexdigest64 = computeXXH3_hexdigest!64;
public alias computeXXH3_hexdigest128 = computeXXH3_hexdigest!128;
