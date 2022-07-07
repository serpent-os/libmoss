/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.driver.lmdb.driver
 *
 * KModule level imports
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.driver.lmdb.iterator;

public import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.driver.lmdb : lmdbStr;
import moss.db.keyvalue.driver.lmdb.transaction : LMDBTransaction;
import lmdb;

/**
 * LMDB specific implementation of a bucket iterator
 */
package final class LMDBIterator : BucketIterator
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
    DatabaseResult reset(in Bucket bucket) @safe
    {
        auto rc = () @trusted {
            this.bucketPrefix = cast(Datum) bucket.prefix;
            return mdb_cursor_open(cast(MDB_txn*) parentTransaction.transaction,
                    cast(MDB_dbi) parentTransaction.dbIndex, &cursor);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
        }

        return NoDatabaseError;
    }

    /**
     * Does this range have more to yield
     */
    override pure bool empty() @safe nothrow return @nogc
    {
        return true;
    }

    /**
     * Front pair of the range
     */
    override pure KeyValuePair front() @safe nothrow return @nogc
    {
        return KeyValuePair(null, null);
    }

    /**
     * Pop the front elemnt and move it along
     */
    override pure void popFront() @safe nothrow return @nogc
    {

    }

private:

    LMDBTransaction parentTransaction;
    Bucket bucket;
    Datum bucketPrefix;
    MDB_cursor* cursor;
}
