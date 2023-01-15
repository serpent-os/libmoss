/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.writer.zstd_token
 *
 * Defines ZstdWriterToken, which transparently compresses payloads
 * in zstd format before flushing them to moss .stone packages.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.writer.zstd_token;

import core.stdc.stdio : FILE;

import moss.format.binary.payload.header;
public import moss.format.binary.writer.token;
import zstd.c.symbols;
import zstd.c.typedefs;
import std.range : chunks;
import std.exception : enforce;

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

        ctx = ZSTD_createCCtx();
        ZSTD_CCtx_setParameter(ctx, CompressionParameter.CompressionLevel, 16);

        /* TODO: Port reader token to C APIs
        ZSTD_CCtx_setParameter(ctx, CompressionParameter.EnableLongDistanceMatching, 1);
        ZSTD_CCtx_setParameter(ctx, CompressionParameter.WindowLog, 31); */

        /* Output */
        immutable outLength = ZSTD_CStreamOutSize();
        outBuf.reserve(outLength);
        outBuf.length = outLength;

        /* Input */
        readSize = ZSTD_CStreamInSize();
    }

    ~this()
    {
        ZSTD_freeCCtx(ctx);
    }

    /**
     * Encode data via the zstd APIs
     */
    override void appendData(ubyte[] data) @trusted
    {
        bool finished;

        immutable readSize = ZSTD_CStreamInSize();
        foreach (element; data.chunks(readSize))
        {
            InBuffer input = InBuffer(element.ptr, element.length, 0);
            do
            {
                OutBuffer output = OutBuffer(outBuf.ptr, outBuf.length, 0);
                auto remaining = ZSTD_compressStream2(ctx, &output, &input,
                        EndDirective.Continue);
                enforce(remaining >= 0, "Compression failure");
                finished = element.length < readSize ? remaining == 0 : input.pos == input.size;

                super.updateStream(input.size, outBuf[0 .. output.pos]);
            }
            while (!finished);
        }

    }

    /**
     * Flush data via the zstd APIs
     */
    override void flush() @trusted
    {
        bool finished;

        InBuffer nullBuffer = InBuffer(null, 0, 0);

        do
        {
            OutBuffer output = OutBuffer(outBuf.ptr, outBuf.length, 0);
            auto remaining = ZSTD_compressStream2(ctx, &output, &nullBuffer, EndDirective.End);
            enforce(remaining >= 0, "Flush failure");

            /* TODO: Again, stop copying, directly write it **/
            super.updateStream(0, outBuf[0 .. output.pos]);
            finished = remaining == 0;
        }
        while (!finished);
    }

private:
    ZSTD_CCtx* ctx;
    ubyte[] outBuf;
    size_t readSize;

}
