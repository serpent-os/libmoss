/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.payload.meta.record
 *
 * Defines the type and binary format of MetaPayload Records.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.payload.meta.record;

public import std.stdint;
import moss.format.binary.endianness;
import moss.format.binary.reader : ReaderToken;
import moss.format.binary.writer : WriterToken;

/**
 * The type of record encountered.
 * We limit this to a small selection of predefined data types.
 */
enum RecordType : uint8_t
{
    Unknown = 0,
    Int8 = 1,
    Uint8 = 2,
    Int16 = 3,
    Uint16 = 4,
    Int32 = 5,
    Uint32 = 6,
    Int64 = 7,
    Uint64 = 8,
    String = 9,
    Dependency = 10,
    Provider = 11,
}

/**
 * We support a predefined set of record types which are additionally
 * tagged for their type.
 */
enum RecordTag : uint16_t
{
    @(RecordType.Unknown) Unknown = 0,

    /** Name of the package */
    @(RecordType.String) Name = 1,

    /** Architecture of the package */
    @(RecordType.String) Architecture = 2,

    /** Version of the package */
    @(RecordType.String) Version = 3,

    /** Summary of the package */
    @(RecordType.String) Summary = 4,

    /** Description of the package */
    @(RecordType.String) Description = 5,

    /** Homepage for the package */
    @(RecordType.String) Homepage = 6,

    /** ID for the source package, used for grouping */
    @(RecordType.String) SourceID = 7,

    /** Runtime dependencies */
    @(RecordType.Dependency) Depends = 8,

    /** Provides some capability or name */
    @(RecordType.Provider) Provides = 9,

    /** Conflicts with some capability or name */
    @(RecordType.Provider) Conflicts = 10,

    /** Release number for the package */
    @(RecordType.Uint64) Release = 11,

    /** SPDX license identifier */
    @(RecordType.String) License = 12,

    /** Currently recorded build number */
    @(RecordType.Uint64) BuildRelease = 13,

    /** Repository index specific (relative URI) */
    @(RecordType.String) PackageURI = 14,

    /** Repository index specific (Package hash) */
    @(RecordType.String) PackageHash = 15,

    /** Repository index specific (size on disk) */
    @(RecordType.Uint64) PackageSize = 16,

    /** A Build Dependency */
    @(RecordType.Dependency) BuildDepends = 17,

    /** Upstream URI for the source */
    @(RecordType.String) SourceURI = 18,

    /** Relative path for the source within the upstream URI */
    @(RecordType.String) SourcePath = 19,

    /** Ref/commit of the upstream source */
    @(RecordType.String) SourceRef = 20,
}

/**
 * Records are found in each moss package after the initial header.
 * They contain all meta-information on the package and are variable
 * length in nature.
 *
 * To skip all records requires skipping the length of every record
 * encountered. The payload will then be encountered before the final 0
 * byte.
 */
extern (C) struct Record
{
align(1):

    /** 4 bytes, endian-aware, total length of the record value */
    @AutoEndian uint32_t length;

    /** 2 bytes, endian-aware, tag for the Record _contextual type_ */
    @AutoEndian RecordTag tag;

    /** 1 byte, key type for the record, i.e. data value type */
    RecordType type;

    /** Reserved, 1 byte padding */
    ubyte[1] padding = 0;

    /**
     * Encode the Record key into the given WriterToken
     */
    void encode(scope WriterToken wr) @trusted
    {
        Record cp = this;

        cp.toNetworkOrder();
        wr.appendData((cast(ubyte*)&cp.length)[0 .. cp.length.sizeof]);
        wr.appendData((cast(ubyte*)&cp.tag)[0 .. cp.tag.sizeof]);
        wr.appendData((cast(ubyte*)&cp.type)[0 .. cp.type.sizeof]);
        wr.appendData((cast(ubyte*)&cp.padding[0])[0 .. cp.padding[0].sizeof]);
    }

    /**
     * Decode the record itself from a given input stream
     */
    void decode(scope ReaderToken rd) @trusted
    {
        auto cp = rd.readDataToStruct!Record;
        cp.toHostOrder();
        this = cp;
    }

    /**
     * Ensure Records aren't insane
     */
    void validate() @safe
    {
        import std.exception : enforce;

        enforce(length > 0, "Record.validate(): Record has empty data");
        enforce(tag != RecordTag.Unknown, "Record.validate(): Unknown tag");
        enforce(type != RecordType.Unknown, "Record.validate(): Unknown type");
        enforce(padding[0] == 0, "Record.validate(): Corrupt padding");
    }
}

static assert(Record.sizeof == 8,
        "Record size must be 8 bytes, not " ~ Record.sizeof.stringof ~ " bytes");
