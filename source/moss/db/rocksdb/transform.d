/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.rocksdb.transform
 *
 * Utility class for working with RocksDB.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.db.rocksdb.transform;

public import rocksdb.slicetransform;

import std.bitmanip : bigEndianToNative;
import std.stdint : uint32_t;
import moss.db.entry;

/**
 * This utility class is responsible for extracting the correct
 * prefix from a specially encoded key to allow bucket behaviour
 * with RocksDB.
 */
public class NamespacePrefixTransform : SliceTransform
{

    /**
     * Construct a new NamespacePrefixTransform
     */
    this()
    {
        super("moss-transform");
    }

    /**
     * Returns true if we detect a special prefix encoding
     */
    override bool inDomain(const Slice inp)
    {
        if (inp.l <= uint32_t.sizeof)
        {
            return false;
        }

        ubyte[uint32_t.sizeof] prefixLenEnc = cast(ubyte[]) inp.p[0 .. uint32_t.sizeof];
        uint32_t prefixLen = bigEndianToNative!(uint32_t, uint32_t.sizeof)(prefixLenEnc);
        return prefixLen > 0;
    }

    /**
     * Return the encoded prefix name from the full key name
     */
    override Slice transform(const Slice inp)
    {
        auto dbe = DatabaseEntry();
        ubyte[] rangedData = cast(ubyte[]) inp.p[0 .. inp.l];
        dbe.decode(rangedData);

        /* Return slice which preserves PrefixLen+Prefix for further matching */
        auto prefixLen = uint32_t.sizeof + dbe.prefix.length;
        return Slice.fromChar(prefixLen, cast(char*) rangedData[0 .. prefixLen]);
    }

    /**
     * Defunct API - needs removing.
     */
    override bool inRange(const Slice inp)
    {
        return false;
    }
}
