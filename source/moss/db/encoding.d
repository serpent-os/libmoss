/*
 * This file is part of moss-db.
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

module moss.db.encoding;

public import moss.db.interfaces : Database, IReadWritable, IReadable;
public import moss.core.encoding;

/**
 * A DbResult is returned from any get() query, but the internal value may not
 * actually be set to anything useful, thus we include a "found" flag for simplistic
 * matching.
 *
 * Future revisions will have the core DB APIs return their own DbFetchResult with
 * a documented status, which we can rewrap with generics in our return.
 */
struct DbResult(V)
{
    /**
     * Value field is set to the value retrieved from the database
     */
    V value = V.init;

    /**
     * Found is set to true if the get query was successful
     */
    bool found = false;
}

/**
 * Allowing using arbitrary keys for bucket based operation and
 * have them properly encoded
 */
pragma(inline, true) auto bucket(P)(Database db, P prefix)
{
    static assert(!is(P == Datum),
            "Database.bucket(): Use .bucketByDatum() for Datum (ubyte[]) keys");
    static assert(isMossEncodable!P, stringifyNonEncodableType!P);
    return db.bucketByDatum(cast(Datum) prefix.mossEncode);
}

/**
 * Strongly typed setter operation for any IReadWritable
 */
pragma(inline, true) void set(K, V)(IReadWritable rwDest, K key, V value)
{
    static assert(isMossEncodable!K, stringifyNonEncodableType!K);
    static assert(isMossEncodable!V, stringifyNonEncodableType!V);

    rwDest.setDatum(cast(Datum) key.mossEncode, cast(Datum) value.mossEncode);
}

/**
 * Strongly typed get operation for any IReadable
 */
public DbResult!V get(V, K)(IReadable rSource, K key)
{
    V val = V.init;
    static assert(isMossEncodable!K, stringifyNonEncodableType!K);
    static assert(isMossDecodable!V, stringifyNonDecodableType!V);

    /* Grab the actual real value */
    ImmutableDatum realValue = cast(ImmutableDatum) rSource.getDatum(cast(Datum) key.mossEncode);
    if (realValue is null || realValue.length < 1)
    {
        return DbResult!V(val, false);
    }
    val.mossDecode(realValue);
    return DbResult!V(val, true);

}
