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
         * Bucket ID
         */
    BucketIdentity bucketID;

    /**
         * Key ID length, follows bucketLength
         */
    uint16_t keyLength;

    /**
         * Pad the struct to 8
         */
    ubyte[2] __padding__;

    /**
     * Encode an entry automatically
     */
    pure ImmutableDatum mossEncode() @trusted
    {
        ubyte[] data;
        data ~= cast(Datum) bucketID.mossEncode;
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
        auto bbytes = rawBytes[0 .. uint32_t.sizeof];
        bucketID.mossDecode(bbytes);
        bbytes = rawBytes[uint32_t.sizeof .. uint32_t.sizeof + uint16_t.sizeof];
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
    BucketIdentity prefix;

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
        assert(this.prefix != 0);
    }
    do
    {
        Entry entry;
        ImmutableDatum entryBytes = () @trusted {
            return cast(ImmutableDatum) rawBytes[0 .. Entry.sizeof];
        }();
        ImmutableDatum keyID = () @trusted {
            return cast(ImmutableDatum) rawBytes[Entry.sizeof .. $];
        }();
        entry.mossDecode(entryBytes);

        () @trusted {
            this.prefix = cast(BucketIdentity) entry.bucketID;
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
     * Usable name for the bucket
     */
    ImmutableDatum name;

    /**
     * Bucket identifier (runtime lookup)
     */
    BucketIdentity identity;
}

/**
 * Iterate buckets in a database
 */
public interface BucketIterator
{
    /**
     * Anything left in this range?
     */
    pure bool empty() @safe nothrow return @nogc;

    /**
     * Bucket at the front of the range
     */
    pure Bucket front() @safe nothrow return @nogc;

    /**
     * Pop the front element and move it along
     */
    void popFront() return @safe;
}

/**
 * Simplistic interface. Iterators are owned by the
 * implementation and should *not* be destroyed.
 */
public interface KeyValueIterator
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
     * Encapsulate creation to not error
     */
    final SumType!(DatabaseError, Bucket) createBucketIfNotExists(scope return ImmutableDatum name) return @safe
    {
        auto result = createBucket(name);
        auto err = result.match!((DatabaseError err2) => err2, (Bucket b) => DatabaseError.init);
        if (err.code == DatabaseErrorCode.BucketExists)
        {
            auto bk = bucket(name);
            if (bk.isNull)
            {
                return result;
            }
            return SumType!(DatabaseError, Bucket)(bk.get);
        }
        return result;
    }

    /**
     * Bucket identity with generics
     */
    final SumType!(DatabaseError, Bucket) createBucket(B)(in B name) return @safe
            if (isMossEncodable!B)
    {
        return createBucket(name.mossEncode);
    }

    /**
     * Mostly error free, generic creation
     */
    final SumType!(DatabaseError, Bucket) createBucketIfNotExists(B)(in B name) return @safe
            if (isMossEncodable!B)
    {
        return createBucketIfNotExists(name.mossEncode);
    }

    /**
     * Lookup an existing bucket
     */
    abstract Nullable!(Bucket, Bucket.init) bucket(scope return ImmutableDatum name) const return @safe;

    /** Ditto */
    final Nullable!(Bucket, Bucket.init) bucket(B)(in B name) const return @safe
            if (isMossEncodable!B)
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
     * Return a KeyValueIterator
     */
    abstract KeyValueIterator iterator(in Bucket bucket) const return @safe;

    /**
     * Generic happy iterator
     */
    final auto iterator(K, V)(in Bucket bucket) const return @safe
            if (isMossDecodable!K && isMossDecodable!V)
    {
        import std.algorithm : map;

        alias RetType = Tuple!(K, "key", V, "value");
        return iterator(bucket).map!((t) {
            K k;
            V v;
            k.mossDecode(t.entry.key);
            v.mossDecode(t.value);
            return RetType(k, v);
        });
    }

    /**
     * Iterate the buckets within the root namespace
     */
    abstract BucketIterator buckets() const return @safe;

    /**
     * Generics happy buckets() iterator with automatic name decoding.
     */
    final auto buckets(T)() const return @safe if (isMossDecodable!T)
    {
        import std.algorithm : map;

        alias RetType = Tuple!(T, "name", Bucket, "bucket");

        return buckets.map!((b) {
            T bucketID;
            bucketID.mossDecode(b.name);
            return RetType(bucketID, b);
        });
    }

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
    final Nullable!(immutable(V), V.init) get(V, K)(in Bucket bucket, in K key) const return @safe
            if (isMossEncodable!K && isMossDecodable!V)
    {
        auto got = get(bucket, key.mossEncode);
        V dec;
        if (got is null)
        {
            return Nullable!(immutable(V), V.init)(V.init);
        }
        dec.mossDecode(got);
        return Nullable!(immutable(V), V.init)(dec);
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
