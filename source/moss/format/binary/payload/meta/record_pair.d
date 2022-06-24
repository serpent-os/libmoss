/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.payload.meta.record_pair
 *
 * Defines the notion of a RecordPair, which is used for encoding/decoding
 * MetaPayloads and their associated Records.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.payload.meta.record_pair;

public import std.stdint;
public import moss.format.binary.payload.meta.record;

import moss.core.encoding;
import moss.format.binary.reader : ReaderToken;
import moss.format.binary.writer : WriterToken;

/**
 * A RecordPair is used internally for encoding/decoding purposes with
 * the MetaPayload and each Record.
 */
extern (C) package struct RecordPair
{
    /**
     * Return the record tag
     */
    pure @property RecordTag tag() @safe @nogc nothrow const
    {
        return record.tag;
    }

    /**
     * Return the record type
     */
    pure @property RecordType type() @safe @nogc nothrow const
    {
        return record.type;
    }

    /**
     * Decode ourselves, Record and associated value, from the input
     * ReaderToken
     */
    void decode(scope ReaderToken rdr) @trusted
    {
        record = Record.init;
        record.decode(rdr);
        record.validate();

        /* Don't decode empty values */
        if (record.length < 1)
        {
            data = null;
            return;
        }

        data = rdr.readData(record.length);
    }

    /**
     * Encode the RecordPair to the underlying stream
     */
    void encode(scope WriterToken wr) @trusted
    {
        record.encode(wr);
        wr.appendData(data);
    }

    /**
     * Decode underlying value to the type in T
     * consumers should check .type before doing so
     */
    pure T get(T)() const
    {
        T decoded;
        decoded.mossDecode(cast(ImmutableDatum) data);
        return decoded;
    }

package:

    void set(T)(RecordType rType, RecordTag rTag, const auto ref T datum)
    {
        static assert(isMossEncodable!T, stringifyNonEncodableType!T);
        data = cast(Datum) datum.mossEncode();
        record.type = rType;
        record.length = cast(uint) data.length;
        record.tag = rTag;
    }

private:

    Datum data;
    Record record;
}
