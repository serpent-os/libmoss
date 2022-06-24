/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.writer.zstd_token
 *
 * Defines ZstdWriterToken, which transparently compresses payloads
 * in zstd format before flushing them to moss .stone packages.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.writer.zstd_token;

import core.stdc.stdio : FILE;

import moss.format.binary.payload.header;
public import moss.format.binary.writer.token;
import zstd : Compressor;

/**
 * The ZstdWriterToken is responsible for zstd stream encoding
 */
final class ZstdWriterToken : WriterToken
{

    @disable this();

    /**
     * Construct new ZstdWriterToken from the given file pointer
     */
    this(FILE* fp) @trusted
    {
        super(fp);

        compressor = new Compressor(16);
    }

    /**
     * Encode data via the zstd APIs
     */
    override ubyte[] encodeData(ref ubyte[] data) @trusted
    {
        return compressor.compress(data);
    }

    /**
     * Flush data via the zstd APIs
     */
    override ubyte[] flushData() @trusted
    {
        return compressor.finish();
    }

private:

    /* Used for zstd APIS */
    Compressor compressor;
}
