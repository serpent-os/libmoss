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

public:

    override pure Bucket bucket(in string name) const return @safe
    {
        return Bucket.init;
    }

    override Nullable!(DatabaseError, DatabaseError.init) set(in Bucket bucket,
            in ImmutableDatum key, in ImmutableDatum value) return @safe
    {
        return NoDatabaseError;
    }

    override Nullable!(DatabaseError, DatabaseError.init) remove(in Bucket bucket,
            in ImmutableDatum key) return @safe
    {
        return NoDatabaseError;

    }

    override BucketIterator iterator(in Bucket bucket) return @safe
    {
        return null;
    }

    override Nullable!(DatabaseError, DatabaseError.init) removeBucket(in Bucket bucket) return @safe
    {
        return NoDatabaseError;
    }

    override ImmutableDatum get(in Bucket bucket, in ImmutableDatum key) const return @safe
    {
        return null;
    }

    override Nullable!(DatabaseError, DatabaseError.init) commit() return @safe
    {
        return Nullable!(DatabaseError, DatabaseError.init)(DatabaseError(
                DatabaseErrorCode.Unimplemented, "Transaction.commit(): unimplemented"));
    }

    override void drop() return @safe
    {

    }

private:

    LMDBDriver parentDriver;
}
