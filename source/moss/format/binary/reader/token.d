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

    /**
     * TODO: Remove or rework this API
     */
    T readDataToStruct(T)()
    {
        return cast(T) 0;
    }

    /**
     * Return a slice from the underlying stream with the given length
     */
    ubyte[] readData(uint64_t length)
    {
        return null;
    }

    /**
     * Return a copy of the underlying header
     */
    pure @property PayloadHeader header() @safe @nogc nothrow const
    {
        return _header;
    }

private:

    PayloadHeader _header;
}
