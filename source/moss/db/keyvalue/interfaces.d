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

public import moss.core.encoding : ImmutableDatum, Datum, isMossEncodable,
    isMossDecodable, mossEncode, mossDecode;
public import moss.db.keyvalue.errors;
public import std.typecons : Tuple;

/**
 * Flags to pass to drivers
 */
public enum DatabaseFlags
{
    /**
     * Default flags are just "read-only"
     */
    None = 1 << 0,

    /**
     * Only open in read only mode - do not attempt creation
     */
    ReadOnly = 1 << 1,

    /**
     * Disable automatic fsync/fdatasync style calls
     *
     * Note: Requires manual flushing
     */
    DisableSync = 1 << 2,

    /**
     * Create database if it doesn't exist
     */
    CreateIfNotExists = 1 << 3,
}

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

/**
 * All interactions with our DB APIs require some form
 * of transaction. In the event of an issue we'll peel
 * back the transaction.
 */
public abstract class Transaction
{
    /**
     * Reset/initialise the Transaction
     */
    abstract DatabaseResult reset() return @safe;

    /**
     * Construct a bucket identity
     */
    pure final Bucket bucket(in ImmutableDatum name) const return @safe
    {
        return Bucket.init;
    }

    /**
     * Set a key in bucket to value (RW view only)
     */
    abstract DatabaseResult set(in Bucket bucket, in ImmutableDatum key, in ImmutableDatum value) return @safe;

    /**
     * Accept generic encoding when not using datums
     */
    final DatabaseResult set(K, V)(in Bucket bucket, in K key, in V val) return @safe
            if (isMossEncodable!K && isMossEncodable!V)
    {
        return set(bucket, key.mossEncode, val.mossEncode);
    }

    /**
     * Remove a key/value pair from a bucket
     */
    abstract DatabaseResult remove(in Bucket bucket, in ImmutableDatum key) return @safe;

    /**
     * Return a BucketIterator
     */
    abstract BucketIterator iterator(in Bucket bucket) return @safe;

    /**
     * Remove a bucket and all children nodes
     */
    abstract DatabaseResult removeBucket(in Bucket bucket) return @safe;

    /**
     * Retrieve a value from the bucket key (RO/RW views)
     */
    abstract ImmutableDatum get(in Bucket bucket, in ImmutableDatum key) const return @safe;
}

/**
 * ExplicitTransactions come from `begin()` API and drivers
 */
public abstract class ExplicitTransaction : Transaction
{
    /**
     * Request commit() for the transaction
     */
    abstract DatabaseResult commit() return @safe;

    /**
     * Request the transaction is aborted
     */
    abstract void drop() return @safe;
}
