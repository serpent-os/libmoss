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
import moss.db.keyvalue.driver.lmdb : lmdbStr;

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

        /* Read-only transaction? */
        immutable cFlags = (parentDriver.databaseFlags & DatabaseFlags.ReadOnly) == DatabaseFlags.ReadOnly
            ? MDB_RDONLY : 0;
        immutable rc = () @trusted {
            return mdb_txn_begin(parentDriver.environment, null, cFlags, &txn);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
        }
        return NoDatabaseError;
    }

public:

    override DatabaseResult set(in Bucket bucket, in ImmutableDatum key, in ImmutableDatum value) return @safe
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.Unimplemented,
                "Transaction.set(): Not yet implemented"));
    }

    override DatabaseResult remove(in Bucket bucket, in ImmutableDatum key) return @safe
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.Unimplemented,
                "Transaction.remove(): Not yet implemented"));
    }

    override BucketIterator iterator(in Bucket bucket) return @safe
    {
        return null;
    }

    override DatabaseResult removeBucket(in Bucket bucket) return @safe
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.Unimplemented,
                "Transaction.removeBucket(): Not yet implemented"));
    }

    override ImmutableDatum get(in Bucket bucket, in ImmutableDatum key) const return @safe
    {
        return null;
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

private:

    LMDBDriver parentDriver;
    MDB_txn* txn;
}
