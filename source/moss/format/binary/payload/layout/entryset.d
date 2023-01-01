/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.payload.layout.entryset
 *
 * Defines the notion of an EntrySet, which describes how a LayoutEntry
 * relates to a source and an optional target.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.payload.layout.entryset;

public import std.stdint;
public import moss.format.binary.payload.layout.entry;

import moss.core : FileType;
import moss.core.encoding;
import moss.format.binary.reader : ReaderToken;
import moss.format.binary.writer : WriterToken;
import std.string : fromStringz;
import std.digest : LetterCase, Order, toHexString;

/**
 * An EntrySet is used to associate an LayoutEntry with a source and optional
 * target.
 */
extern (C) public struct EntrySet
{
    /**
     * The underlying LayoutEntry
     */
    LayoutEntry entry;

    /**
     * Final destination path on disk
     */
    string target;

    /**
     * Decode ourselves, LayoutEntry and associated source/target, from the input
     * ReaderToken
     */
    void decode(scope ReaderToken rdr) @trusted
    {
        entry.decode(rdr);

        /* Source is always first */
        if (entry.sourceLength > 0)
        {
            sourceData = rdr.readData(entry.sourceLength).dup();
        }

        /* And target follows */
        if (entry.targetLength < 1)
        {
            return;
        }

        const auto data = rdr.readData(entry.targetLength);
        target.mossDecode(cast(ImmutableDatum) data);
    }

    /**
     * Return source data for copying
     */
    pure @property const(ubyte[]) data() @safe @nogc nothrow const
    {
        return sourceData;
    }

    /**
     * Returns the digest for the entryset
     */
    pure @property const(ubyte[]) digest() @safe @nogc nothrow const
    {
        assert(entry.type == FileType.Regular);
        return sourceData;
    }

    /**
     * Return digest as a string
     */
    pure @property auto digestString() @trusted nothrow const
    {
        return cast(string) toHexString!(LetterCase.lower, Order.increasing)(digest).dup;
    }

    /**
     * Return the symlink origin
     */
    pure @property const(string) symlinkSource() @trusted nothrow const
    {
        string ret;
        ret.mossDecode(cast(ImmutableDatum) sourceData);
        return ret;
    }

    /**
     * Encode the EntrySet to the underlying stream
     */
    void encode(scope WriterToken wr) @trusted
    {
        /* Write record + value */
        auto strings = encodeStrings();
        entry.sourceLength = cast(uint16_t) sourceData.length;
        if (strings !is null)
        {
            entry.targetLength = cast(uint16_t) strings.length;
        }
        entry.encode(wr);
        if (entry.sourceLength > 0)
        {
            wr.appendData(sourceData.dup());
        }
        wr.appendData(strings);
    }

    /**
     * Encode this entry set into a ubyte sequence
     */
    ImmutableDatum mossEncode() @trusted const
    {
        auto encoded = encodeStrings();
        LayoutEntry entCopy = cast() entry;
        if (encoded !is null)
        {
            entCopy.targetLength = cast(uint16_t) encoded.length;
        }

        return cast(ImmutableDatum)((cast(ubyte[]) entry.mossEncode()) ~ sourceData ~ encoded);
    }

    /**
     * Decode this EntrySet from a ubyte sequence
     */
    void mossDecode(in ImmutableDatum rawBytes)
    {
        this = EntrySet.init;
        entry.mossDecode(rawBytes);

        /* No strings follow */
        if (LayoutEntry.sizeof + 1 >= rawBytes.length)
        {
            return;
        }

        ImmutableDatum remainingBytes = rawBytes[LayoutEntry.sizeof .. $];
        if (entry.sourceLength > 0)
        {
            sourceData = remainingBytes[0 .. entry.sourceLength].dup();
        }

        /* And target follows */
        if (entry.targetLength < 1)
        {
            return;
        }

        ImmutableDatum data = remainingBytes[entry.sourceLength .. $];
        target.mossDecode(data);
    }

package:

    ubyte[] sourceData;

private:

    ubyte[] encodeStrings() @trusted const
    {
        import std.exception : enforce;

        ubyte[] encoded = null;

        if (target !is null && target.length > 0)
        {
            enforce(target.length < uint16_t.max, "encode(): String length too long");
            encoded ~= target.mossEncode();
        }

        return encoded;
    }

}
