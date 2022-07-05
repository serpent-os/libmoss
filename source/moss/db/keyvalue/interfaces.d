/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.interfaces
 *
 * API design for the project (inspired heavily by boltdb)
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.interfaces;

public import moss.core.encoding : ImmutableDatum, Datum;
public import moss.db.keyvalue.errors;
public import std.typecons : Tuple;

/**
 * A "Bucket" is merely a referential identifier for
 * a compartment of storage in the database and offers
 * no direct API itself.
 *
 */
public struct Bucket
{
    /**
     * Bucket identifier
     */
    ImmutableDatum prefix;
}

/**
 * Simplistic interface. Iterators are owned by the
 * implementation and should *not* be destroyed.
 */
public interface BucketIterator
{
    /**
     * All iterations are performed with key and value in lockstep
     */
    static alias KeyValuePair = Tuple!(ImmutableDatum, "key", ImmutableDatum, "value");

    /**
     * Does this range have more to yield
     */
    pure bool empty() @safe nothrow return @nogc;

    /**
     * Front pair of the range
     */
    pure KeyValuePair front() @safe nothrow return @nogc;

    /**
     * Pop the front elemnt and move it along
     */
    pure void popFront() @safe nothrow return @nogc;
}
