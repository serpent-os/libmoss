/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.driver.lmdb.transaction
 *
 * LMDB Transactions
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.driver.lmdb.transaction;

public import moss.db.keyvalue.driver;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.driver.lmdb.driver : LMDBDriver;
import moss.db.keyvalue.driver.lmdb : lmdbStr, encodeKey;
import moss.db.keyvalue.driver.lmdb.iterator;
import std.exception : assumeUnique;
import lmdb;
import std.string : toStringz;

/**
 * LMDB Transaction implementation.
 */
package class LMDBTransaction : ExplicitTransaction
{
    @disable this();

    /**
     * Construct a driver with the given parent
     */
    this(LMDBDriver parentDriver, bool canWrite) @safe @nogc nothrow
    {
        this.parentDriver = parentDriver;
        this.canWrite = canWrite;
    }

    /**
     * Reset this transaction ready for use.
     */
    override DatabaseResult reset() return @safe
    {
        if (txn !is null)
        {
            () @trusted { mdb_txn_reset(txn); }();
            return NoDatabaseError;
        }
        int cFlagsTxn;
        int cFlags;

        if ((parentDriver.databaseFlags & DatabaseFlags.ReadOnly) == DatabaseFlags.ReadOnly)
        {
            cFlags = MDB_RDONLY;
            cFlagsTxn = MDB_RDONLY;
        }
        else if (!canWrite)
        {
            cFlagsTxn = MDB_RDONLY;
        }

        if (
            (parentDriver.databaseFlags & DatabaseFlags.CreateIfNotExists) == DatabaseFlags
                .CreateIfNotExists)
        {
            cFlags |= MDB_CREATE;
        }

        auto rc = () @trusted {
            return mdb_txn_begin(parentDriver.environment, null, cFlagsTxn, &txn);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
        }

        /* Open the main data table */
        rc = () @trusted {
            return mdb_dbi_open(txn, "data".toStringz, cFlags, &dbi);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.ConnectionFailed, lmdbStr(rc)));
        }

        /* Meta table */
        rc = () @trusted {
            return mdb_dbi_open(txn, "meta".toStringz, cFlags, &dbiMeta);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.ConnectionFailed, lmdbStr(rc)));
        }

        /* bucket table */
        rc = () @trusted {
            return mdb_dbi_open(txn, "bucketMap".toStringz, cFlags, &dbiBucketMap);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.ConnectionFailed, lmdbStr(rc)));
        }

        /* free list of old buckets */
        rc = () @trusted {
            return mdb_dbi_open(txn, "freeList".toStringz, cFlags, &dbiFreeList);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.ConnectionFailed, lmdbStr(rc)));
        }
        return NoDatabaseError;
    }

public:

    /**
     * Create and store a bucket internally - assigning a unique identity
     */
    override SumType!(DatabaseError, Bucket) createBucket(scope return ImmutableDatum name) return @safe
    {
        return SumType!(DatabaseError, Bucket)(DatabaseError(DatabaseErrorCode.Unimplemented,
                "LMDBTransaction.createBucket(): Not yet implemented"));
    }

    /**
     * Update or insert a key/value pair.
     */
    override DatabaseResult set(in Bucket bucket, in ImmutableDatum key, in ImmutableDatum value) return @safe
    {
        MDB_val dbKey = encodeKey(bucket, key);
        MDB_val dbVal = () @trusted {
            return MDB_val(cast(size_t) value.length, cast(void*)&value[0]);
        }();

        /* try to write it */
        auto rc = () @trusted { return mdb_put(txn, dbi, &dbKey, &dbVal, 0); }();

        /* hit an error */
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
        }
        return NoDatabaseError;
    }

    /**
     * Remove a key from the bucket if it exists
     */
    override DatabaseResult remove(in Bucket bucket, in ImmutableDatum key) return @safe
    {
        MDB_val dbKey = encodeKey(bucket, key);
        auto rc = () @trusted { return mdb_del(txn, dbi, &dbKey, null); }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.KeyNotFound, lmdbStr(rc)));
        }
        return NoDatabaseError;
    }

    /**
     * Return a new iterator for the given bucket
     */
    override BucketIterator iterator(in Bucket bucket) const return @safe
    {
        auto iter = new LMDBIterator(this);
        iter.reset(bucket);
        return iter;
    }

    /**
     * Consume a new writable iterator and wipe everything in the bucket
     */
    override DatabaseResult removeBucket(in Bucket bucket) return @safe
    {
        auto iter = new LMDBIterator(this);
        iter.reset(bucket);
        return iter.wipeBucket();
    }

    /**
     * Retrieve a buckets key from the database
     */
    override ImmutableDatum get(in Bucket bucket, in ImmutableDatum key) const return @safe
    {
        MDB_val dbKey = encodeKey(bucket, key);
        MDB_val dbVal;
        immutable rc = () @trusted {
            return mdb_get(cast(MDB_txn*) txn, cast(MDB_dbi) dbi, &dbKey, &dbVal);
        }();
        if (rc != 0)
        {
            return null;
        }
        return () @trusted {
            return cast(ImmutableDatum) dbVal.mv_data[0 .. dbVal.mv_size];
        }();
    }

    /**
     * Commit, via mdb_txn_commit
     */
    override Nullable!(DatabaseError, DatabaseError.init) commit() return @safe
    {
        immutable rc = () @trusted { return mdb_txn_commit(txn); }();
        if (rc != 0)
        {
            return Nullable!(DatabaseError, DatabaseError.init)(
                    DatabaseError(DatabaseErrorCode.Transaction, lmdbStr(rc)));
        }
        return NoDatabaseError;
    }

    /**
     * Abort the TXN
     */
    override void drop() return @safe
    {
        () @trusted { mdb_txn_abort(txn); txn = null; }();
    }

    pure @property auto transaction() @safe @nogc nothrow const
    {
        return txn;
    }

    pure @property auto dbIndex() @safe @nogc nothrow const
    {
        return dbi;
    }

private:

    /**
     * Grab the existing identity increment if it exists, otherwise
     * we set to 0.
     * Increment if it does, storing the latest.
     */
    SumType!(BucketIdentity, DatabaseError) nextBucketIdentity() return @safe
    {
        BucketIdentity nextIdentity;
        MDB_val lookupVal;
        MDB_val storeVal;

        MDB_val lookupKey = () @trusted {
            auto str = "next-available-bucket-index";
            return MDB_val(cast(size_t) str.length + 1, cast(void*) str.toStringz);
        }();
        auto rc = () @trusted {
            return mdb_get(txn, dbiMeta, &lookupKey, &lookupVal);
        }();

        /* Not an error, just needs storing */
        if (rc == MDB_NOTFOUND)
        {
            nextIdentity = 0;
        }
        else if (rc != 0)
        {
            /* Some genuine error.. */
            return SumType!(BucketIdentity, DatabaseError)(
                    DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
        }
        else
        {
            /* Retrieve the old value and increment by one */
            ImmutableDatum storedValue = () @trusted {
                return cast(ImmutableDatum) lookupVal.mv_data[0 .. lookupVal.mv_size];
            }();
            nextIdentity.mossDecode(storedValue);
            nextIdentity++;
        }

        /* Stick it into the new value */
        rc = () @trusted {
            ImmutableDatum storage = nextIdentity.mossEncode();
            storeVal.mv_data = cast(void*)&storage[0];
            storeVal.mv_size = storage.length;
            return mdb_put(txn, dbiMeta, &lookupKey, &storeVal, 0);
        }();

        if (rc != 0)
        {
            return SumType!(BucketIdentity, DatabaseError)(
                    DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
        }

        return SumType!(BucketIdentity, DatabaseError)(nextIdentity);
    }

    LMDBDriver parentDriver;
    MDB_txn* txn;
    MDB_dbi dbi;
    MDB_dbi dbiMeta;
    MDB_dbi dbiBucketMap;
    MDB_dbi dbiFreeList; /* Old bucket identities going free */
    bool canWrite;
}
