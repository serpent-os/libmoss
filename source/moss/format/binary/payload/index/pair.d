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

module moss.format.binary.payload.index.pair;

public import std.stdint;
public import moss.format.binary.payload.index.entry;

import moss.format.binary.reader : ReaderToken;
import moss.format.binary.writer : WriterToken;

/**
 * An EntryPair is used to associate an IndexEntry with a string value,
 * which is the encoded ID for the IndexEntry.
 */
extern (C) package struct EntryPair
{
    /**
     * The underlying IndexEntry
     */
    IndexEntry entry;

    string id;

    /**
     * Decode ourselves, IndexEntry and associated value, from the input
     * ReaderToken
     */
    void decode(scope ReaderToken rdr) @trusted
    {
        entry.decode(rdr);

        /* Don't decode empty values */
        if (entry.length < 1)
        {
            return;
        }

        /* Grab the value */
        const auto data = rdr.readData(entry.length);
        auto strlength = cast(long) entry.length;
        id = cast(string) data[0 .. strlength - 1];
    }

    /**
     * Encode the EntryPair to the underlying stream
     */
    void encode(scope WriterToken wr) @trusted
    {
        import std.exception : enforce;
        import std.string : toStringz;

        /* Stash length before writing entry to file */
        auto z = toStringz(id);
        assert(id.length < uint16_t.max, "encode(): String Length too long");
        entry.length = cast(uint16_t)(id.length + 1);
        auto len = entry.length;

        /* Write record + string value */
        entry.encode(wr);
        ubyte[] emitted = (cast(ubyte*) z)[0 .. len];
        wr.appendData(emitted);
    }
}
