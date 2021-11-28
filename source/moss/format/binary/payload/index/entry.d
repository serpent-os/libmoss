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

module moss.format.binary.payload.index.entry;

public import std.stdint;

import moss.format.binary.endianness;
import moss.format.binary.reader : ReaderToken;
import moss.format.binary.writer : WriterToken;
import std.digest : LetterCase, Order, toHexString;

/**
 * An IndexEntry identifies a unique file within the file payload.
 * It records the size of the file - along with the number of times
 * the file is used within the package (deduplication statistics).
 *
 * The length refers to the *value* length of the IndexEntry, i.e. how
 * long the name is.
 */
extern (C) struct IndexEntry
{
align(1):

    /** 8-bytes, endian aware, start offset to the file */
    @AutoEndian uint64_t start;

    /** 8-bytes, endian aware, end offset of the file */
    @AutoEndian uint64_t end; /* 8 bytes */

    /** xxh3_128bit hash digest */
    ubyte[16] digest = 0;

    /**
     * Encode the IndexEntry to the underlying stream
     */
    void encode(scope WriterToken wr) @trusted
    {
        IndexEntry cp = this;

        cp.toNetworkOrder();
        wr.appendData((cast(ubyte*)&cp.start)[0 .. cp.start.sizeof]);
        wr.appendData((cast(ubyte*)&cp.end)[0 .. cp.end.sizeof]);
        wr.appendData(cp.digest);
    }

    /**
     * Decode the entry itself from a given input stream
     */
    void decode(scope ReaderToken rd) @trusted
    {
        auto cp = rd.readDataToStruct!IndexEntry;
        cp.toHostOrder();
        this = cp;
    }

    /**
     * Compute the size of the associated content
     */
    pragma(inline, true) pure @property uint64_t contentSize() @safe @nogc nothrow const
    {
        return end - start;
    }

    /**
     * Return hex encoded string of the digest
     */
    pragma(inline, true) pure @property auto digestString() @safe @nogc nothrow const
    {
        return toHexString!(LetterCase.lower, Order.increasing)(digest);
    }
}

static assert(IndexEntry.sizeof == 32,
        "IndexEntry size must be 32 bytes, not " ~ IndexEntry.sizeof.stringof ~ " bytes");
