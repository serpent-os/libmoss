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

module moss.format.binary.payload.index;

public import moss.format.binary.payload;
public import std.typecons : Tuple;

/**
 * The currently writing version for IndexPayload
 */
const uint16_t indexPayloadVersion = 1;

/**
 * Nice iterable type in foreach aggregate
 */
alias RangedEntryPair = Tuple!(IndexEntry, "entry", string, "id");

/**
 * An IndexPayload contains a set of offsets to unique files contained within
 * a ContentPayload, and can be viewed akin to a lookup table. Each file is
 * stored in sequence without padding, thus an offset lookup helps to split
 * a singular blob into several files again.
 */
final class IndexPayload : Payload
{

public:

    /**
     * Create a new instance of IndexPayload
     */
    this() @safe
    {
        super(PayloadType.Index, indexPayloadVersion);
    }

    /**
     * We ensure we're registered correctly with the Reader subsystem
     */
    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!IndexPayload(PayloadType.Index);
    }

    /**
     * Return true when the Range is complete.
     */
    pure @property bool empty() @safe @nogc nothrow
    {
        const long pairLength = cast(long) pairs.length;
        return (pairs.length < 1 || iterationIndex > pairLength - 1);
    }

    /**
     * Pop the front EntryPair from the list and proceed to the next one.
     */
    void popFront() @safe @nogc nothrow
    {
        ++iterationIndex;
    }

    /**
     * Return the front item of the list
     */
    RangedEntryPair front() @trusted @nogc nothrow const
    {
        RangedEntryPair ret;
        const auto pair = &pairs[iterationIndex];
        ret.entry = pair.entry;
        ret.id = pair.id;
        return ret;
    }

    /**
     * Encode the IndexPayload to the WriterToken
     */
    override void encode(scope WriterToken wr) @trusted
    {
        /* Ensure every pair is encoded via WriterToken API */
        foreach (index; 0 .. pairs.length)
        {
            auto pair = &pairs[index];
            pair.encode(wr);
        }
    }

    /**
     * Decode the IndexPayload from the ReaderToken
     */
    override void decode(scope ReaderToken rdr) @trusted
    {
        /* Match number of records */
        recordCount = rdr.header.numRecords;

        foreach (recordIndex; 0 .. recordCount)
        {
            pairs ~= EntryPair();
            auto length = cast(long) pairs.length;
            auto pair = &pairs[length - 1];
            pair.decode(rdr);
        }
    }

    /**
     * Add an Index by ID to the underlying pair set.
     */
    void addIndex(IndexEntry entry, const(string) id) @trusted
    {
        pairs ~= EntryPair();
        auto length = cast(long) pairs.length;
        auto pair = &pairs[length - 1];
        recordCount = cast(uint32_t) length;
        pair.entry = entry;
        pair.id = id;
    }

private:

    EntryPair[] pairs;
    ulong iterationIndex = 0;
}

public import moss.format.binary.payload.index.entry;
public import moss.format.binary.payload.index.pair;
