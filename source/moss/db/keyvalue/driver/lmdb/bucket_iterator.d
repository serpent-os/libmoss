/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.driver.lmdb.bucket_iterator
 *
 * KModule level imports
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.driver.lmdb.bucket_iterator;

public import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.driver.lmdb : lmdbStr, encodeKey;
import moss.db.keyvalue.driver.lmdb.transaction : LMDBTransaction;
import lmdb;
import std.typecons : Nullable;

/**
 * LMDB specific implementation of a key value iterator
 */
package final class LMDBBucketIterator : BucketIterator
{
    @disable this();

    /**
     * Construct a new iterator for the given transaction
     */
    this(in LMDBTransaction parentTransaction) return @safe nothrow @nogc
    {
        /* Required abuse */
        () @trusted {
            this.parentTransaction = cast(LMDBTransaction) parentTransaction;
        }();
    }

    /**
     * Attempt to reset the iterator (new | RO only)
     */
    DatabaseResult reset() @safe
    {
        auto rc = () @trusted {
            return mdb_cursor_open(cast(MDB_txn*) parentTransaction.transaction,
                    cast(MDB_dbi) parentTransaction.bucketIndex, &cursor);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
        }

        firstRun = true;
        bucketName = null;
        bucketIdentity = 0;
        popFront();

        return NoDatabaseError;
    }

    /**
     * Does this range have more to yield
     */
    override pure bool empty() @safe nothrow return @nogc
    {
        if (bucketIdentity == 0 || bucketName is null)
        {
            return true;
        }
        return false;
    }

    /**
     * Front pair of the range
     */
    override pure Bucket front() @safe nothrow return @nogc
    {
        return () @trusted {
            return Bucket(cast(ImmutableDatum) bucketName, bucketIdentity);
        }();
    }

    /**
     * Pop the front elemnt and move it along
     */
    override void popFront() return @safe
    {
        immutable nextMode = firstRun ? MDB_cursor_op.next : MDB_cursor_op.next;
        MDB_val dbKey;
        MDB_val dbVal;

        auto rc = () @trusted {
            return mdb_cursor_get(cursor, &dbKey, &dbVal, nextMode);
        }();
        firstRun = false;

        /* Run out of things. */
        if (rc != 0)
        {
            bucketIdentity = 0;
            bucketName = null;
            return;
        }

        /* Set key/value */
        auto keyData = () @trusted {
            return cast(Datum) dbKey.mv_data[0 .. dbKey.mv_size];
        }();
        auto valData = () @trusted {
            return cast(Datum) dbVal.mv_data[0 .. dbVal.mv_size];
        }();

        () @trusted {
            bucketIdentity.mossDecode(cast(ImmutableDatum) valData);
            bucketName = keyData;
        }();
    }

private:

    LMDBTransaction parentTransaction;
    MDB_cursor* cursor;
    bool firstRun = false;

    Datum bucketName;
    BucketIdentity bucketIdentity;
}
