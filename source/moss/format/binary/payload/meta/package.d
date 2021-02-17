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
     * Subclasses must implement the decode method so that reading of the
     * stream data is possible.
     */
    override void decode(scope ReaderToken* rdr) @trusted
    {
        import std.stdio : writeln;

        import moss.format.binary.endianness : toHostOrder;

        /* Match number of records */
        recordCount = rdr.header.numRecords;

        foreach (recordIndex; 0 .. recordCount)
        {
            RecordPair pair;
            pair.decode(rdr);
        }

        writeln("MetaPayload.decode(): IMPLEMENT ME");
    }

    /**
     * Subclasses must implement the encode method so that writing of the
     * stream data is possible.
     */
    override void encode(scope WriterToken* wr) @trusted
    {
        import std.stdio : writeln;

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
    void addRecord(R : RecordTag, T)(R key, auto const ref T datum) @system
    {
        import std.traits : EnumMembers, OriginalType;
        import std.stdio : writeln;
        import std.conv : to;
        import std.exception : enforce;

        pairs ~= RecordPair();
        auto length = cast(long) pairs.length;
        auto pair = &pairs[length - 1];
        pair.tag = key;
        recordCount = cast(uint32_t) length;

        static foreach (i, m; EnumMembers!RecordTag)
        {
            if (i == key)
            {

                mixin("enum memberName = __traits(identifier, EnumMembers!RecordTag[i]);");
                mixin("enum attrs = __traits(getAttributes, RecordTag." ~ to!string(
                        memberName) ~ ");");
                static assert(attrs.length == 1,
                        "Missing validation tag for RecordTag." ~ to!string(memberName));

                pair.type = attrs[0];
                static if (is(T == string))
                {
                    switch (attrs[0])
                    {

                    case RecordType.String:
                        assert(typeid(OriginalType!T) == typeid(string),
                                "addRecord(RecordTag." ~ memberName ~ ") expects string, not " ~ typeof(datum)
                                .stringof);
                        writeln("Writing key: ", key, " - value: ", datum);
                        pair.val_string = datum;
                        break;
                    default:
                        assert(0, "INCOMPLETE SUPPORT");
                    }
                }
                else
                {
                    switch (attrs[0])
                    {

                    case RecordType.Int8:
                        assert(typeid(OriginalType!T) == typeid(int8_t),
                                "addRecord(RecordTag." ~ memberName ~ ") expects int8_t, not " ~ typeof(datum)
                                .stringof);
                        writeln("Writing key: ", key, " - value: ", datum);
                        pair.val_i8 = cast(int8_t) datum;
                        break;
                    case RecordType.Uint8:
                        assert(typeid(OriginalType!T) == typeid(uint8_t),
                                "addRecord(RecordTag." ~ memberName ~ ") expects uint8_t, not " ~ typeof(datum)
                                .stringof);
                        writeln("Writing key: ", key, " - value: ", datum);
                        pair.val_u8 = cast(uint8_t) datum;
                        break;

                    case RecordType.Int16:
                        assert(typeid(OriginalType!T) == typeid(int16_t),
                                "addRecord(RecordTag." ~ memberName ~ ") expects int16_t, not " ~ typeof(datum)
                                .stringof);
                        writeln("Writing key: ", key, " - value: ", datum);
                        pair.val_i16 = cast(int16_t) datum;
                        break;
                    case RecordType.Uint16:
                        assert(typeid(OriginalType!T) == typeid(uint16_t),
                                "addRecord(RecordTag." ~ memberName ~ ") expects uint16_t, not " ~ typeof(datum)
                                .stringof);
                        writeln("Writing key: ", key, " - value: ", datum);
                        pair.val_u16 = cast(uint16_t) datum;
                        break;
                    case RecordType.Int32:
                        assert(typeid(OriginalType!T) == typeid(int32_t),
                                "addRecord(RecordTag." ~ memberName ~ ") expects int32_t, not " ~ typeof(datum)
                                .stringof);
                        writeln("Writing key: ", key, " - value: ", datum);
                        pair.val_i32 = cast(int32_t) datum;
                        break;
                    case RecordType.Uint32:
                        assert(typeid(OriginalType!T) == typeid(uint32_t),
                                "addRecord(RecordTag." ~ memberName ~ ") expects uint32_t, not " ~ typeof(datum)
                                .stringof);
                        writeln("Writing key: ", key, " - value: ", datum);
                        pair.val_u32 = cast(uint32_t) datum;
                        break;
                    case RecordType.Int64:
                        assert(typeid(OriginalType!T) == typeid(int64_t),
                                "addRecord(RecordTag." ~ memberName ~ ") expects int64_t, not " ~ typeof(datum)
                                .stringof);
                        writeln("Writing key: ", key, " - value: ", datum);
                        pair.val_i64 = cast(int64_t) datum;
                        break;
                    case RecordType.Uint64:
                        assert(typeid(OriginalType!T) == typeid(uint64_t),
                                "addRecord(RecordTag." ~ memberName ~ ") expects uint64_t, not " ~ typeof(datum)
                                .stringof);
                        writeln("Writing key: ", key, " - value: ", datum);
                        pair.val_u64 = cast(uint64_t) datum;
                        break;
                    default:
                        assert(0, "INCOMPLETE SUPPORT");
                    }
                }
            }
        }

        enforce(pair.type != RecordType.Unknown, "Unable to marshal " ~ R.stringof);
    }

private:

    RecordPair[] pairs;
}

public import moss.format.binary.payload.meta.record;
