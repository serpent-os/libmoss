/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.payload.index
 *
 * Defines the notion of a binary IndexPayload.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.payload.index;

public import moss.format.binary.payload;

/**
 * The currently writing version for IndexPayload
 */
const uint16_t indexPayloadVersion = 1;

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
        const long entryLength = cast(long) entries.length;
        auto isEmpty = (entries.length < 1 || iterationIndex > entryLength - 1);

        if (isEmpty)
        {
            iterationIndex = 0;
        }

        return isEmpty;
    }

    /**
     * Pop the front IndexEntry from the list and proceed to the next one.
     */
    void popFront() @safe @nogc nothrow
    {
        ++iterationIndex;
    }

    /**
     * Return the front item of the list
     */
    IndexEntry front() @trusted @nogc nothrow const
    {
        const auto entry = &entries[iterationIndex];
        return *entry;
    }

    /**
     * Encode the IndexPayload to the WriterToken
     */
    override void encode(scope WriterToken wr) @trusted
    {
        /* Ensure every entry is encoded via WriterToken API */
        foreach (index; 0 .. entries.length)
        {
            auto entry = &entries[index];
            entry.encode(wr);
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
            entries ~= IndexEntry();
            auto length = cast(long) entries.length;
            auto entry = &entries[length - 1];
            entry.decode(rdr);
        }
    }

    /**
     * Add an Index by ID to the underlying entry set.
     */
    void addIndex(IndexEntry entry) @trusted
    {
        entries ~= entry;
        auto length = cast(long) entries.length;
        recordCount = cast(uint32_t) length;
    }

private:

    IndexEntry[] entries;
    ulong iterationIndex = 0;
}

public import moss.format.binary.payload.index.entry;
