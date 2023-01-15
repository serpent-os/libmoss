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

import zstd.highlevel.context : DecompressionStream;

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
        decompressor = new DecompressionStream();
    }

    /**
     * Decode up to LENGTH bytes from the stream and pass it back,
     */
    override ubyte[] decodeData(uint64_t length) @trusted
    {
        while (availableStorage < length)
        {
            /* How much can we currently read? */
            auto readableSize = remainingBytes <= chunkSize ? remainingBytes : chunkSize;
            auto bytesRead = decompressor.decompress(readRaw(readableSize));
            bufferStorage ~= bytesRead;
            availableStorage += bytesRead.length;
        }

        auto retStore = bufferStorage[0 .. length];
        scope (exit)
        {
            bufferStorage = bufferStorage[length .. $];
            availableStorage -= length;
        }
        return retStore;
    }

private:

    DecompressionStream decompressor;

    /* Saved bytes from decompression runs */
    ubyte[] bufferStorage;

    /* How many bytes to bulk process */
    static const uint chunkSize = 128 * 1024;

    ulong availableStorage = 0;
}
