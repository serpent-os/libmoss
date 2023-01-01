/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.reader.token
 *
 * Defines the notion of a ReaderToken, which is used to control access
 * to the underlying Reader resource by exposing slices into it.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.reader.token;

public import std.stdint : uint64_t;
public import moss.format.binary.payload.header;

/**
 * The ReaderToken base type permits access to the underlying Reader resource
 * in a controlled fashion, allowing implementations to add custom behaviour
 * such as decompression.
 *
 * The toplevel ReaderToken is responsible for providing a standard API and
 * ensuring that hash checks are valid, etc.
 */
public abstract class ReaderToken
{
    @disable this();

    /**
     * Supertype constructor to handle data storage
     */
    this(ref ubyte[] rangedData)
    {
        this.rangedData = rangedData;
    }

    /**
     * TODO: Remove or rework this API
     *
     * Attempts to read data from the stream and de-serialise into a C-style
     * struct.
     */
    T readDataToStruct(T)()
    {
        T tmpVar;
        const ubyte[] data = readData(T.sizeof);
        T* tmpPtr = cast(T*) data.ptr;
        tmpVar = *tmpPtr;
        return tmpVar;
    }

    /**
     * Return a slice from the underlying stream with the given length
     */
    final ubyte[] readData(uint64_t length)
    {
        return decodeData(length);
    }

    /**
     * Implementations should make decodeData actually useful.
     */
    abstract ubyte[] decodeData(uint64_t length) @trusted;

    /**
     * Return a copy of the underlying header
     */
    pure @property PayloadHeader header() @safe @nogc nothrow const
    {
        return _header;
    }

package:

    /**
     * Set the internal PayloadHeader for decoding purposes
     */
    pure @property void header(PayloadHeader header) @safe @nogc nothrow
    {
        _header = header;
    }

    /**
     * Helper function to read a raw number of bytes without conversion, and
     * enforce safety limits
     */
    final ubyte[] readRaw(uint64_t length) @safe
    {
        import std.exception : enforce;

        /* Ensure we update the filePointer on successful reads */
        scope (exit)
        {
            filePointer += length;
        }

        enforce(filePointer + length <= rangedData.length,
                "ReaderToken.readRaw(): Cannot pull additional bytes past EOF");

        return rangedData[filePointer .. $];
    }

    /**
     * Return how many bytes are currently left within the stream
     */
    pragma(inline, true) pure final @property uint64_t remainingBytes() @safe @nogc nothrow
    {
        return _header.storedSize - filePointer;
    }

private:

    PayloadHeader _header;
    ubyte[] rangedData;

    uint64_t filePointer = 0;
}

/**
 * PlainReaderToken provides the default implementation of ReaderToken that
 * works with plain (non-compressed) data.
 */
public final class PlainReaderToken : ReaderToken
{
    @disable this();

    /**
     * Construct a new PlainReaderToken with the range of data made available
     * from the memory mapped file.
     */
    this(ref ubyte[] rangedData)
    {
        super(rangedData);
    }

    /**
     * Pull raw bytes directly from the stream.
     */
    override ubyte[] decodeData(uint64_t length) @trusted
    {
        return super.readRaw(length);
    }
}

public import moss.format.binary.reader.zstd_token;
