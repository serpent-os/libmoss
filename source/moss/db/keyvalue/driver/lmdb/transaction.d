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

/**
 * LMDB Transaction implementation.
 */
package class LMDBTransaction : ExplicitTransaction
{
    @disable this();

    /**
     * Construct a driver with the given parent
     */
    this(LMDBDriver parentDriver) @safe @nogc nothrow
    {
        this.parentDriver = parentDriver;
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

        /* Open the default table (no multitable stuff) */
        rc = () @trusted { return mdb_dbi_open(txn, null, cFlags, &dbi); }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.ConnectionFailed, lmdbStr(rc)));
        }
        return NoDatabaseError;
    }

public:

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

    override DatabaseResult removeBucket(in Bucket bucket) return @safe
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.Unimplemented,
                "Transaction.removeBucket(): Not yet implemented"));
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

    LMDBDriver parentDriver;
    MDB_txn* txn;
    MDB_dbi dbi;
}
