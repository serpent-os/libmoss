/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.payload.index.entry
 *
 * Defines the notion of an IndexEntry (indexes ContentPayloads entries).
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.payload.index.entry;

public import std.stdint;

import moss.format.binary.endianness;
import moss.format.binary.reader : ReaderToken;
import moss.format.binary.writer : WriterToken;
import std.digest : LetterCase, Order, toHexString;

/**
 * An IndexEntry contains the offsets of a unique file within the
 * ContentPayload along with the XXHash3 (128bit) digest for the
 * file.
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
