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
    ReadOnly = 1 << 2,

    /**
     * Create the DB if it doesn't already exist.
     */
    CreateIfNotExists = 1 << 2,

    /**
     * Disable automatic fsync/fdatasync style calls
     *
     * Note: Requires manual flushing
     */
    DisableSync = 1 << 3,
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
public interface Transaction
{
    /**
     * Construct a bucket identity
     */
    pure Bucket bucket(in string name) const return @safe;

    /**
     * Set a key in bucket to value (RW view only)
     */
    void set(in Bucket bucket, in ImmutableDatum key, in ImmutableDatum value) return @safe;

    /**
     * Remove a key/value pair from a bucket
     */
    void remove(in Bucket bucket, in ImmutableDatum key) return @safe;

    /**
     * Return a BucketIterator
     */
    BucketIterator iterator(in Bucket bucket) return @safe;

    /**
     * Remove a bucket and all children nodes
     */
    void removeBucket(in Bucket bucket) return @safe;

    /**
     * Retrieve a value from the bucket key (RO/RW views)
     */
    ImmutableDatum get(in Bucket bucket, in ImmutableDatum key) const return @safe;
}
