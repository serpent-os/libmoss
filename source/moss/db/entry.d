/* SPDX-License-Identifier: Zlib */

/**
 * moss.db.entry
 *
 * Define the notion of a moss database entry.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.db.entry;

public import moss.core : Datum;

import std.bitmanip : nativeToBigEndian, bigEndianToNative;
import std.exception : enforce;
import std.stdint : uint32_t;

/**
 * A DatabaseEntry is composed of a prefix ("bucket") and a distinct key ID
 * It is used by our internal implementations to handle bucket separation
 * in instances where it is not natively supported.
 */
struct DatabaseEntry
{
    /**
     * Prefix or "bucket ID" for the entry
     */
    Datum prefix;

    /**
     * Actual key without any prefix or modification
     */
    Datum key;

    /**
     * Construct a DatabaseEntry as shallow references to input data.
     */

    this(scope const(Datum) prefix, scope const(Datum) key)
    {
        this.prefix = cast(Datum) prefix;
        this.key = cast(Datum) key;
    }

    /**
     * Encode the DatabaseEntry into a prefixed key with a fixed uint32_t prefix
     * length.
     */
    pure Datum encode()
    {
        uint32_t prefixLen = prefix is null ? 0 : cast(uint32_t) prefix.length;
        ubyte[uint32_t.sizeof] encodedLen = nativeToBigEndian(prefixLen);

        /* Empty prefix? */
        if (prefixLen < 1)
        {
            /* Just returning an encoded empty prefix + key */
            if (key is null)
            {
                return encodedLen.dup;
            }

            /* Return empty prefix + key */
            return encodedLen ~ key;
        }

        /* Have prefix name but no key */
        if (key is null)
        {
            return encodedLen ~ prefix;
        }

        /* Full prefix + key combination */
        return encodedLen ~ prefix ~ key;
    }

    /**
     * Decode this DatabaseEntry from the input bytes
     */
    void decode(scope Datum input)
    {
        enforce(input.length >= uint32_t.sizeof, "DatabaseEntry.decode(Datum): Key is too short");

        ubyte[uint32_t.sizeof] prefixLenEnc = input[0 .. uint32_t.sizeof];
        const uint32_t prefixLen = bigEndianToNative!(uint32_t, uint32_t.sizeof)(prefixLenEnc);

        static const auto prefixA = uint32_t.sizeof;
        const auto prefixB = prefixLen + uint32_t.sizeof;

        this.prefix = input[prefixA .. prefixB];
        this.key = input[prefixB .. $];
    }
}
