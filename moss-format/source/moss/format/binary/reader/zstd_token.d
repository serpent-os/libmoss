/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.reader.zstd_token
 *
 * Defines an zstd compression aware ReaderToken implementation.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.reader.zstd_token;

public import moss.format.binary.reader.token;

import zstd.c.typedefs;
import zstd.c.symbols;
import zstd.common;
import std.exception : enforce;
import std.string : format, fromStringz;

extern (C) size_t ZSTD_decompressStream(ZSTD_DCtx* ctx, OutBuffer* output, InBuffer* input);

/**
 * The ZstdReaderToken provides a zstd-stream-decompression aware ReaderToken
 * implementation.
 */
public final class ZstdReaderToken : ReaderToken
{
    @disable this();

    /**
     * Construct a new ZstdReaderToken with the range of data made available
     * from the memory mapped file.
     */
    this(ref ubyte[] rangedData)
    {
        super(rangedData);
        ZSTD_DCtx_reset(ctx, ResetDirective.Session_only);
    }

    static this()
    {
        ctx = ZSTD_createDCtx();
        ZSTD_DCtx_setParameter(ctx, DecompressionParameter.WindowLogMax, 31);
        readSize = ZSTD_DStreamInSize();
        writeSize = ZSTD_DStreamOutSize();
        outBuffer.reserve(writeSize);
        outBuffer.length = writeSize;
    }

    static ~this()
    {
        ZSTD_freeDCtx(ctx);
    }

    /**
     * Decode up to LENGTH bytes from the stream and pass it back,
     */
    override ubyte[] decodeData(uint64_t length) @trusted
    {
        while (availableStorage < length)
        {
            readChunk();
        }

        auto ret = cachedStorage[0 .. length];
        cachedStorage = cachedStorage[length .. $];
        availableStorage -= length;
        return ret;
    }

private:

    /** 
     * Read the next (readSize) chunk of zstd data and cache via GC
     * TODO: Use a dynamic RingBuffer and pop the front
     */
    void readChunk() @trusted
    {
        /* How much needs reading? */
        immutable chunkSize = remainingBytes <= readSize ? remainingBytes : readSize;

        /* Read a single chunk */
        auto rawBytes = readRaw(chunkSize);

        auto input = InBuffer(rawBytes.ptr, rawBytes.length, 0);

        while (input.pos < input.size)
        {
            auto output = OutBuffer(outBuffer.ptr, writeSize, 0);
            const ret = ZSTD_decompressStream(ctx, &output, &input);
            enforce(!ZSTD_isError(ret), format!"zstd: %s"(ZSTD_getErrorName(ret).fromStringz));
            availableStorage += output.pos;
            cachedStorage ~= outBuffer[0 .. output.pos];
        }
    }

    /* How much is cached? */
    ulong availableStorage;
    ubyte[] cachedStorage;

    static ZSTD_DCtx* ctx;
    static ulong readSize;
    static ulong writeSize;
    static ubyte[] outBuffer;
}
