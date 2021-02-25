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

module moss.format.binary.reader.token;

public import std.stdint : uint64_t;
public import moss.format.binary.payload.header;
public import std.digest.crc : CRC64ISO;

/**
 * The ReaderToken base type permits access to the underlying Reader resource
 * in a controlled fashion, allowing implementations to add custom behaviour
 * such as decompression.
 *
 * The toplevel ReaderToken is responsible for providing a standard API and
 * ensuring that CRC64ISO checks are valid, etc.
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
        checksum.start();
    }

    /**
     * TODO: Remove or rework this API
     *
     * Attempts to read data from the stream and deserialise into a C-style
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
        ubyte[] data = decodeData(length);
        checksum.put(data);
        return data;
    }

    /**
     * Finish reading
     */
    final void finish() @trusted
    {
        import std.exception : enforce;

        crc64iso = checksum.finish();
        enforce(filePointer == rangedData.length, "Incorrect length read");
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
     * Return the calculated CRC64ISO value
     */
    pragma(inline, true) pure final @property ubyte[8] crc64iso() @safe @nogc nothrow
    {
        return _crc64iso;
    }

private:

    /**
     * Set the known CRC64ISO value
     */
    pragma(inline, true) pure @property void crc64iso(ubyte[8] newChecksum) @safe @nogc nothrow
    {
        _crc64iso = newChecksum;
    }

    PayloadHeader _header;
    ubyte[] rangedData;
    CRC64ISO checksum;
    ubyte[8] _crc64iso = [0, 0, 0, 0, 0, 0, 0, 0];

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
