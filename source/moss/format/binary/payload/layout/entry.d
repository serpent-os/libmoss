/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.payload.layout.entry
 *
 * Defines the notion of a LayoutEntry. It describes file origin paths.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.payload.layout.entry;

public import std.stdint;

import moss.format.binary.endianness;
import moss.core : FileType, ImmutableDatum;
import moss.format.binary.reader : ReaderToken;
import moss.format.binary.writer : WriterToken;

/**
 * A LayoutEntry is a multipart key that defines the origin of
 * a constructed path.
 *
 * The corresponding value of the key will contain two values,
 * the origin, and the target. In all regular file cases, the
 * origin will be a hash ID so that files may be linked out from
 * the system hash store.
 *
 * In the instance of directories, the origin will be blank and skipped.
 * In the case of symlinks, the origin will be the source of the symlink.
 * And finally, for special files (mkdev) the origin will be the uint32_t
 * device number encoded as a uint32_t.
 *
 * The tag field is reserved for internal use, allowing individual paths
 * to be flagged as a certain *kind* of file, which may in turn trigger
 * some kind of action.
 */
extern (C) struct LayoutEntry
{
align(1):

    /** 4-bytes, endian aware, owning user ID */
    @AutoEndian uint32_t uid = 0;

    /** 4-bytes, endian aware, owning group ID */
    @AutoEndian uint32_t gid = 0;

    /** 4-bytes, endian aware, mode/permissions */
    @AutoEndian uint32_t mode = 0;

    /** 4-bytes, endian aware, tag for the file meta type (usage) */
    @AutoEndian uint32_t tag = 0;

    /** 2-bytes, endian aware, length for the source (ID) parameter */
    @AutoEndian uint16_t sourceLength = 0; /* 2 bytes */

    /** 2-bytes, endian aware, length for the target (path) parameter */
    @AutoEndian uint16_t targetLength = 0; /* 2 bytes */

    /** 1 byte, type of the destination file */
    FileType type = FileType.Unknown;

    /** 11-byte array, reserved padding */
    ubyte[11] padding = 0;

    /**
     * Encode the LayoutEntry to the underlying byte buffer
     */
    void encode(scope WriterToken wr) @trusted
    {
        LayoutEntry cp = this;
        cp.toNetworkOrder();

        wr.appendData((cast(ubyte*)&cp.uid)[0 .. cp.uid.sizeof]);
        wr.appendData((cast(ubyte*)&cp.gid)[0 .. cp.gid.sizeof]);
        wr.appendData((cast(ubyte*)&cp.mode)[0 .. cp.mode.sizeof]);
        wr.appendData((cast(ubyte*)&cp.tag)[0 .. cp.tag.sizeof]);
        wr.appendData((cast(ubyte*)&cp.sourceLength)[0 .. cp.sourceLength.sizeof]);
        wr.appendData((cast(ubyte*)&cp.targetLength)[0 .. cp.targetLength.sizeof]);
        wr.appendData((cast(ubyte*)&cp.type)[0 .. cp.type.sizeof]);
        wr.appendData(cp.padding);
    }

    /**
     * Encode this entry into a ubyte sequence
     */
    ImmutableDatum mossEncode()
    {
        LayoutEntry cp = this;
        cp.toNetworkOrder();

        auto ret = cast(ImmutableDatum)(
                (cast(ubyte*)&cp.uid)[0 .. cp.uid.sizeof] ~ (cast(
                ubyte*)&cp.gid)[0 .. cp.gid.sizeof] ~ (cast(
                ubyte*)&cp.mode)[0 .. cp.mode.sizeof] ~ (cast(
                ubyte*)&cp.tag)[0 .. cp.tag.sizeof] ~ (cast(
                ubyte*)&cp.sourceLength)[0 .. cp.sourceLength.sizeof] ~ (cast(
                ubyte*)&cp.targetLength)[0 .. cp.targetLength.sizeof] ~ (
                cast(ubyte*)&cp.type)[0 .. cp.type.sizeof] ~ cp.padding);
        return ret;
    }

    /**
     * Decode the entry itself from a given input stream
     */
    void decode(scope ReaderToken rd) @trusted
    {
        auto cp = rd.readDataToStruct!LayoutEntry();
        cp.toHostOrder();
        this = cp;
    }

    /**
     * Decode the entry itself from a given ubyte sequence
     */
    void mossDecode(in ImmutableDatum rawBytes)
    {
        import std.exception : enforce;

        enforce(rawBytes.length >= LayoutEntry.sizeof,
                "LayoutEntry.mossDecode(): Invalid stream size");
        LayoutEntry* cp = cast(LayoutEntry*) rawBytes.ptr[0 .. LayoutEntry.sizeof];
        this = *cp;
        this.toHostOrder();
    }
}

static assert(LayoutEntry.sizeof == 32,
        "LayoutEntry size must be 32 bytes, not " ~ LayoutEntry.sizeof.stringof ~ " bytes");
