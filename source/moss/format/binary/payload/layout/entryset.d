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
        entry.encode(wr);
        wr.appendData(sourceData.dup());
        wr.appendData(strings);
    }

    /**
     * Encode this entry set into a ubyte sequence
     */
    ImmutableDatum mossEncode()
    {
        return cast(ImmutableDatum)((cast(ubyte[]) entry.mossEncode()) ~ sourceData ~ encodeStrings());
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

    ubyte[] encodeStrings() @trusted
    {
        import std.exception : enforce;

        ubyte[] encoded = null;

        if (target !is null && target.length > 0)
        {
            enforce(target.length < uint16_t.max, "encode(): String length too long");
            entry.targetLength = cast(uint16_t)(target.length + 1);
            encoded ~= target.mossEncode();
        }

        return encoded;
    }

}
