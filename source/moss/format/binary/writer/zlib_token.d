/*
 * This file is part of moss-format.
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

module moss.format.binary.writer.zlib_token;

import core.stdc.stdio : FILE;

import moss.format.binary.payload.header;
public import moss.format.binary.writer.token;
import std.zlib : Compress;

/**
 * The Zlib is responsible for zlib stream encoding
 */
final class ZlibWriterToken : WriterToken
{

    @disable this();

    /**
     * Construct new ZlibWriterToken from the given file pointer
     */
    this(FILE* fp) @trusted
    {
        super(fp);

        compressor = new Compress(6);
    }

    /**
     * Encode data via the zlib APIs
     */
    override ubyte[] encodeData(ref ubyte[] data) @trusted
    {
        return cast(ubyte[]) compressor.compress(data);
    }

    /**
     * Flush data via the zlib APIs
     */
    override ubyte[] flushData() @trusted
    {
        return cast(ubyte[]) compressor.flush();
    }

private:

    /* Used for zlib APIS */
    Compress compressor;
}
