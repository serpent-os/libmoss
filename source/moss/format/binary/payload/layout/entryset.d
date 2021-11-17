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

import moss.core.encoding;
import moss.format.binary.reader : ReaderToken;
import moss.format.binary.writer : WriterToken;

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
     * Originator source for the file, i.e. symlink or regular file source
     */
    string source;

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
            const auto data = rdr.readData(entry.sourceLength);
            source.mossDecode(cast(ImmutableDatum) data);
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
     * Encode the EntrySet to the underlying stream
     */
    void encode(scope WriterToken wr) @trusted
    {
        /* Write record + value */
        auto strings = encodeStrings();
        entry.encode(wr);
        wr.appendData(strings);
    }

    /**
     * Encode this entry set into a ubyte sequence
     */
    ImmutableDatum mossEncode()
    {
        return cast(ImmutableDatum)((cast(ubyte[]) entry.mossEncode()) ~ encodeStrings());
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

        /* Source is always first */
        if (entry.sourceLength > 0)
        {
            const auto data = remainingBytes[0 .. entry.sourceLength];
            source.mossDecode(data);
        }

        /* And target follows */
        if (entry.targetLength < 1)
        {
            return;
        }

        ImmutableDatum data = remainingBytes[entry.sourceLength .. $];
        target.mossDecode(data);
    }

private:

    ubyte[] encodeStrings() @trusted
    {
        import std.exception : enforce;

        ubyte[] encoded = null;

        if (source !is null && source.length > 0)
        {
            enforce(source.length < uint16_t.max, "encode(): String length too long");
            entry.sourceLength = cast(uint16_t)(source.length + 1);
            encoded ~= source.mossEncode();
        }

        if (target !is null && target.length > 0)
        {
            enforce(target.length < uint16_t.max, "encode(): String length too long");
            entry.targetLength = cast(uint16_t)(target.length + 1);
            encoded ~= target.mossEncode();
        }

        return encoded;
    }
}
