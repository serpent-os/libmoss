/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.writer.zlib_token
 *
 * Defines a ZlibWriterToken, which transparently compresses payloads
 * in zlib format before flushing them to moss .stone packages.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.writer.zlib_token;

import core.stdc.stdio : FILE;

import moss.format.binary.payload.header;
public import moss.format.binary.writer.token;
import std.zlib : Compress;

/**
 * The ZlibWriterToken is responsible for zlib stream encoding
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
