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
    ubyte[] readData(uint64_t length)
    {
        throw new Exception("readData(): Not yet implemented");
    }

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

private:

    PayloadHeader _header;
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
}

public import moss.format.binary.reader.zstd_token;
