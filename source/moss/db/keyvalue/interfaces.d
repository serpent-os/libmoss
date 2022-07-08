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
import std.conv : to;
public import std.stdint : uint8_t, uint16_t, uint32_t;
import std.exception : assumeUnique;

/**
 * Each bucket name is mapped to an incrementing integer.
 * Each implementation should recycle if possible, to prevent
 * running out of bucket identities.
 */
public alias BucketIdentity = uint32_t;

/**
 * Defines the type of every record key (entry)
 */
extern (C) public enum EntryType : uint8_t
{
    /**
     * Entry is just a bucket
     */
    Bucket = 0,

    /**
     * Entry is a key
     */
    Key = 1,
}

/**
 * Mostly used for internal (de/se)rialisation
 */
extern (C) public struct Entry
{
align(1):
    /**
         * Type
         */
    EntryType type;

    /**
         * Bucket ID length, follows
         */
    uint16_t bucketLength;

    /**
         * Key ID length, follows bucketLength
         */
    uint16_t keyLength;

    /**
         * Pad the struct to 8
         */
    ubyte[3] __padding__;

    /**
     * Encode an entry automatically
     */
    pure ImmutableDatum mossEncode() @trusted
    {
        ubyte[] data;
        data ~= cast(Datum) type.mossEncode;
        data ~= cast(Datum) bucketLength.mossEncode;
        data ~= cast(Datum) keyLength.mossEncode;
        data ~= __padding__;
        return assumeUnique(data);
    }

    /**
     * Decode an entry
     */
    void mossDecode(in ImmutableDatum rawBytes) @safe
    {
        assert(rawBytes.length == Entry.sizeof);
        ulong offset = 0;
        type.mossDecode(rawBytes[0 .. EntryType.sizeof]);
        auto bbytes = rawBytes[EntryType.sizeof .. EntryType.sizeof + uint16_t.sizeof];
        bucketLength.mossDecode(bbytes);
        bbytes = rawBytes[EntryType.sizeof + uint16_t.sizeof .. EntryType.sizeof
            + uint16_t.sizeof + uint16_t.sizeof];
        keyLength.mossDecode(bbytes);

    }
}

static assert(Entry.sizeof == 8,
        "Entry.sizeof() != 8 bytes, instead it is " ~ Entry.sizeof.to!string ~ " bytes");

/**
 * Concrete encapsulation of a database entry
 */
public struct DatabaseEntry
{
    /**
     * Bucket identifier
     */
    Datum prefix;

    /**
     * Actual key
     */
    Datum key;

    /**
     * Decode from a byte stream.
     *
     * Params:
     *      rawBytes = Input stream
     */
    void mossDecode(in ImmutableDatum rawBytes) @safe
    in
    {
        assert(rawBytes.length > Entry.sizeof);
    }
    out
    {
        assert(this.prefix !is null);
    }
    do
    {
        Entry entry;
        ImmutableDatum entryBytes = () @trusted {
            return cast(ImmutableDatum) rawBytes[0 .. Entry.sizeof];
        }();
        ImmutableDatum remainder = () @trusted {
            return cast(ImmutableDatum) rawBytes[Entry.sizeof .. $];
        }();
        entry.mossDecode(entryBytes);

        ImmutableDatum bucketID = remainder[0 .. entry.bucketLength];
        ImmutableDatum keyID = remainder[entry.bucketLength .. entry.bucketLength + entry.keyLength];

        () @trusted {
            this.prefix = cast(Datum) bucketID;
            this.key = cast(Datum) keyID;
        }();
    }
}

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
     * Bucket identifier (encoded)
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
    static alias EntryValuePair = Tuple!(immutable(DatabaseEntry), "entry",
            ImmutableDatum, "value");

    /**
     * Does this range have more to yield
     */
    pure bool empty() @safe nothrow return @nogc;

    /**
     * Front pair of the range
     */
    pure EntryValuePair front() @safe nothrow return @nogc;

    /**
     * Pop the front elemnt and move it along
     */
    void popFront() return @safe;
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
     * Create a new bucket for use.
     */
    abstract SumType!(DatabaseError, Bucket) createBucket(scope return ImmutableDatum name) return @safe;

    /**
     * Bucket identity with generics
     */
    final SumType!(DatabaseError, Bucket) createBucket(B)(in B name) return @safe
            if (isMossEncodable!B)
    {
        return createBucket(name.mossEncode);
    }

    /**
     * Construct a bucket identity
     */
    pure final Bucket bucket(scope return ImmutableDatum name) const return @safe
    {
        return Bucket(name);
    }

    /** Ditto */
    pure final Bucket bucket(B)(in B name) const return @safe if (isMossEncodable!B)
    {
        return bucket(name.mossEncode);
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
    abstract BucketIterator iterator(in Bucket bucket) const return @safe;

    /**
     * Remove a bucket and all children nodes
     */
    abstract DatabaseResult removeBucket(in Bucket bucket) return @safe;

    /**
     * Retrieve a value from the bucket key (RO/RW views)
     */
    abstract ImmutableDatum get(in Bucket bucket, in ImmutableDatum key) const return @safe;

    /**
     * Accept generic encoding when not using datums
     */
    final immutable(V) get(K, V)(in Bucket bucket, in K key) const return @safe
            if (isMossEncodable!K && isMossDecodable!V)
    {
        V inr;
        inr.mossDecode(get(bucket, key.mossEncode));
        return inr;
    }
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
