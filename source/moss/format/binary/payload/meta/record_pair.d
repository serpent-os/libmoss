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
