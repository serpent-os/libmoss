/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.driver.lmdb.driver
 *
 * KModule level imports
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.driver.lmdb.iterator;

public import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.driver.lmdb : lmdbStr, encodeKey;
import moss.db.keyvalue.driver.lmdb.transaction : LMDBTransaction;
import lmdb;
import std.typecons : Nullable;

/**
 * LMDB specific implementation of a key value iterator
 */
package final class LMDBIterator : KeyValueIterator
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
            this.bucketPrefix = cast(BucketIdentity) bucket.identity;
            this.bucketName = cast(Datum) bucket.name;
            return mdb_cursor_open(cast(MDB_txn*) parentTransaction.transaction,
                    cast(MDB_dbi) parentTransaction.dbIndex, &cursor);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
        }

        canSet = true;
        popFront();

        return NoDatabaseError;
    }

    /**
     * Does this range have more to yield
     */
    override pure bool empty() @safe nothrow return @nogc
    {
        if (keyCurrent.isNull || valCurrent is null)
        {
            return true;
        }
        return false;
    }

    /**
     * Front pair of the range
     */
    override pure EntryValuePair front() @safe nothrow return @nogc
    {
        return () @trusted {
            return EntryValuePair(cast(immutable(DatabaseEntry)) keyCurrent.get,
                    cast(ImmutableDatum) valCurrent);
        }();
    }

    /**
     * Pop the front elemnt and move it along
     */
    override void popFront() return @safe
    {
        immutable nextMode = canSet ? MDB_cursor_op.setRange : MDB_cursor_op.next;
        MDB_val dbKey;
        MDB_val dbVal;

        auto rc = () @trusted {
            if (canSet)
            {
                dbKey = encodeKey(Bucket(cast(ImmutableDatum) bucketName, bucketPrefix), [
                        ]);
            }
            return mdb_cursor_get(cursor, &dbKey, &dbVal, nextMode);
        }();
        canSet = false;

        if (rc != 0)
        {
            keyCurrent = DatabaseEntry.init;
            valCurrent = null;
            return;
        }

        /* Set key/value */
        auto keyData = () @trusted {
            return cast(Datum) dbKey.mv_data[0 .. dbKey.mv_size];
        }();
        valCurrent = () @trusted {
            return cast(Datum) dbVal.mv_data[0 .. dbVal.mv_size];
        }();

        auto dbEntry = () @trusted {
            auto dbe = DatabaseEntry();
            dbe.mossDecode(cast(ImmutableDatum) keyData);
            return dbe;
        }();

        /* Bucket has changed - nothing to show. */
        if (dbEntry.prefix != bucketPrefix)
        {
            keyCurrent = DatabaseEntry.init;
            valCurrent = null;
            return;
        }

        keyCurrent = dbEntry;
    }

    /**
     * Walk all entries in a bucket and empty it
     */
    DatabaseResult wipeBucket() return @safe
    {
        foreach (entry, val; this)
        {
            auto rc = () @trusted { return mdb_cursor_del(cursor, 0); }();
            if (rc != 0)
            {
                return DatabaseResult(DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
            }
        }
        return NoDatabaseError;
    }

private:

    LMDBTransaction parentTransaction;
    BucketIdentity bucketPrefix;
    Datum bucketName;
    MDB_cursor* cursor;

    Nullable!(DatabaseEntry, DatabaseEntry.init) keyCurrent;
    Datum valCurrent;
    bool canSet;
}
