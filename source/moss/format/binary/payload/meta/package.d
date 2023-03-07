/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.payload.meta
 *
 * Defines the notion of a MetaPayload, which provides a Key/Value storage
 * mechanism for payload metadata.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.payload.meta;

public import moss.format.binary.payload;

import moss.format.binary.payload.meta.record_pair;

/**
 * The currently writing version for MetaPayload
 */
const uint16_t metaPayloadVersion = 1;

/**
 * A MetaPayload provides a simple Key/Value storage mechanism for metadata
 * within a payload blob. Each key is strongly typed to the value and is
 * tagged with a given context *type*, such as "Name", "Summary", etc.
 *
 * The MetaPayload, when populated, contains all useful information on a
 * package, as seen from the package manager.
 */
final class MetaPayload : Payload
{

public:

    /**
     * Each implementation must call the base constructor to ensure that
     * the PayloadType property has been correctly set.
     */
    this() @safe
    {
        super(PayloadType.Meta, metaPayloadVersion);
    }

    /**
     * We ensure we're registered correctly with the Reader subsystem
     */
    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!MetaPayload(PayloadType.Meta);
    }

    /** 
     * Return the full pkgID for a given meta payload
     */
    string getPkgID()
    {
        import std.algorithm : each;
        import std.exception : enforce;
        import std.string : format;

        string pkgName = null;
        uint64_t pkgRelease = 0;
        string pkgVersion = null;
        string pkgArchitecture = null;

        foreach (ref t; pairs)
        {
            switch (t.tag)
            {
            case RecordTag.Name:
                pkgName = t.get!string;
                break;
            case RecordTag.Release:
                pkgRelease = t.get!uint64_t();
                break;
            case RecordTag.Version:
                pkgVersion = t.get!string();
                break;
            case RecordTag.Architecture:
                pkgArchitecture = t.get!string();
                break;
            default:
                break;
            }
        }

        enforce(pkgName !is null, "getPkgID(): Missing Name field");
        enforce(pkgVersion !is null, "getPkgID(): Missing Version field");
        enforce(pkgArchitecture !is null, "getPkgID(): Missing Architecture field");

        return "%s-%s-%d.%s".format(pkgName, pkgVersion, pkgRelease, pkgArchitecture);
    }

    /**
     * Return true when the Range is complete.
     */
    pure @property bool empty() @safe @nogc nothrow
    {
        const long pairLength = cast(long) pairs.length;
        auto isEmpty = (pairs.length < 1 || iterationIndex > pairLength - 1);

        /* Reset */
        if (isEmpty)
        {
            iterationIndex = 0;
        }

        return isEmpty;
    }

    /**
     * Pop the front RecordPair from the list and proceed to the next one.
     */
    void popFront() @safe @nogc nothrow
    {
        ++iterationIndex;
    }

    /**
     * Return the front item of the list
     */
    ref const(RecordPair) front() @trusted @nogc nothrow const
    {
        return pairs[iterationIndex];
    }

    /**
     * Subclasses must implement the decode method so that reading of the
     * stream data is possible.
     */
    override void decode(scope ReaderToken rdr) @trusted
    {
        /* Match number of records */
        recordCount = rdr.header.numRecords;

        foreach (recordIndex; 0 .. recordCount)
        {
            pairs ~= RecordPair();
            auto length = cast(long) pairs.length;
            auto pair = &pairs[length - 1];
            pair.decode(rdr);
        }
    }

    /**
     * Subclasses must implement the encode method so that writing of the
     * stream data is possible.
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
     * Add a new Record to the pair set for future encoding
     */
    void addRecord(T)(RecordType type, RecordTag tag, auto const ref T datum) @system
    {
        import std.traits : EnumMembers, OriginalType;
        import std.conv : to;
        import std.exception : enforce;

        pairs ~= RecordPair();
        auto length = cast(long) pairs.length;
        auto pair = &pairs[length - 1];
        recordCount = cast(uint32_t) length;

        pair.set(type, tag, datum);
    }

private:

    RecordPair[] pairs;
    ulong iterationIndex = 0;
}

public import moss.format.binary.payload.meta.record;
