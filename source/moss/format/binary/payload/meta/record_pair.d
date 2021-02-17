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

import moss.format.binary.reader : ReaderToken;
import moss.format.binary.writer : WriterToken;

/**
 * A RecordPair is used internally for encoding/decoding purposes with
 * the MetaPayload and each Record.
 */
extern (C) package struct RecordPair
{
    /**
     * Fixed tag for the Record key
     */
    RecordTag tag;

    /**
     * Fixed type for the Record value *type*
     */
    RecordType type;

    /**
     * Anonymous union containing all potential values so
     * that we can store a RecordPair in memory with its
     * associated value
     */
    union
    {
        uint8_t val_u8;
        uint16_t val_u16;
        uint32_t val_u32;
        uint64_t val_u64;
        int8_t val_i8;
        int16_t val_i16;
        int32_t val_i32;
        int64_t val_i64;
        string val_string;
    }

    /**
     * Decode ourselves, Record and associated value, from the input
     * ReaderToken
     */
    void decode(scope ReaderToken* rdr) @trusted
    {
        Record rcrd;
        rcrd.decode(rdr);

        tag = rcrd.tag;
        type = rcrd.type;

        /* Don't decode empty values */
        if (rcrd.length < 1)
        {
            return;
        }

        final switch (type)
        {
        case RecordType.Int8:
            decodeNumeric(val_i8, &rcrd, rdr);
            break;
        case RecordType.Uint8:
            decodeNumeric(val_u8, &rcrd, rdr);
            break;
        case RecordType.Int16:
            decodeNumeric(val_i16, &rcrd, rdr);
            break;
        case RecordType.Uint16:
            decodeNumeric(val_u16, &rcrd, rdr);
            break;
        case RecordType.Int32:
            decodeNumeric(val_i32, &rcrd, rdr);
            break;
        case RecordType.Uint32:
            decodeNumeric(val_u32, &rcrd, rdr);
            break;
        case RecordType.Int64:
            decodeNumeric(val_i64, &rcrd, rdr);
            break;
        case RecordType.Uint64:
            decodeNumeric(val_u64, &rcrd, rdr);
            break;
        case RecordType.String:
            const auto data = rdr.readData(rcrd.length);
            auto strlength = cast(long) rcrd.length;
            val_string = cast(string) data[0 .. strlength - 1];
            break;
        case RecordType.Unknown:
            assert(0 == 0,
                    "RecordPair.encode(): Unknown encoding not supported");
        }
    }

    /**
     * Encode the RecordPair to the underlying stream
     */
    void encode(scope WriterToken* wr) @trusted
    {
        Record r = Record();
        r.type = this.type;
        r.tag = this.tag;

        final switch (r.type)
        {
        case RecordType.Int8:
            encodeNumeric(val_i8, &r, wr);
            break;
        case RecordType.Uint8:
            encodeNumeric(val_u8, &r, wr);
            break;
        case RecordType.Int16:
            encodeNumeric(val_i16, &r, wr);
            break;
        case RecordType.Uint16:
            encodeNumeric(val_u16, &r, wr);
            break;
        case RecordType.Int32:
            encodeNumeric(val_i32, &r, wr);
            break;
        case RecordType.Uint32:
            encodeNumeric(val_u32, &r, wr);
            break;
        case RecordType.Int64:
            encodeNumeric(val_i64, &r, wr);
            break;
        case RecordType.Uint64:
            encodeNumeric(val_u64, &r, wr);
            break;
        case RecordType.String:
            encodeString(val_string, &r, wr);
            break;
        case RecordType.Unknown:
            assert(0 == 0,
                    "RecordPair.encode(): Unknown encoding not supported");
        }
    }

private:

    /**
     * Endian-aware helper that can decode the range of numerics we support
     * from the underlying stream data
     */
    void decodeNumeric(T)(ref T datum, scope Record* record, scope ReaderToken* rdr)
    {
        import std.exception : enforce;
        import std.bitmanip : bigEndianToNative;

        enforce(record.length == T.sizeof, "Record size mistmatch");

        auto readData = rdr.readData(T.sizeof);

        static if (T.sizeof > 1)
        {
            version (LittleEndian)
            {
                datum = bigEndianToNative!(T, T.sizeof)(readData[0 .. T.sizeof]);
            }
            else
            {
                datum = *cast(T*) readData.ptr;
            }
        }
        else
        {
            datum = *cast(T*) readData.ptr;
        }
    }

    /**
     * Handle encoding of all our numeric data types in a generic way, also
     * ensuring correct endian encoding.
     */
    void encodeNumeric(T)(ref T datum, scope Record* record, scope WriterToken* wr)
    {
        import std.bitmanip : nativeToBigEndian;
        import std.stdio : fwrite;
        import std.exception : enforce;

        /* Stash length before writing record to file */
        record.length = cast(uint32_t) T.sizeof;

        /* Write record to file */
        record.encode(wr);

        /* Ensure we encode big-endian values only */
        version (BigEndian)
        {
            wr.appendData((cast(ubyte*)&datum)[0 .. T.sizeof]);
        }
        else
        {
            static if (T.sizeof > 1)
            {
                ubyte[T.sizeof] b = nativeToBigEndian(datum);
                wr.appendData(b);
            }
            else
            {
                /* Add single byte */
                wr.appendData(datum);
            }
        }
    }

    /**
     * Special-case handling, encode a string to the stream.
     * Essentially we expect a UTF-8 array with no endian worries,
     * and write this as a NUL terminated C string
     */
    void encodeString(ref string datum, scope Record* record, scope WriterToken* wr)
    {
        import std.exception : enforce;
        import std.string : toStringz;

        /* Stash length before writing record to file */
        auto z = toStringz(datum);
        assert(datum.length < uint32_t.max, "encodeString(): String Length too long");
        record.length = cast(uint32_t) datum.length + 1;
        auto len = record.length;

        /* Write record + string value */
        record.encode(wr);
        ubyte[] emitted = (cast(ubyte*) z)[0 .. len];
        wr.appendData(emitted);
    }
}
