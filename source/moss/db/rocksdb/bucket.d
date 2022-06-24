/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.rocksdb.bucket
 *
 * Defines the notion of a RocksDB bucket.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.db.rocksdb.bucket;

public import moss.core : Datum;
public import moss.db.interfaces : IReadWritable, IIterable;

import moss.db.entry;
import moss.db.rocksdb.db : RDBDatabase;
import moss.db.rocksdb.iterator : RDBIterator;
import rocksdb.options : ReadOptions;
import rocksdb.iterator;

/**
 * In our rocksdb wrapper we have the root bucket, which may be nested, or
 * the actual nested bucket. In either case it is the root buckets job to
 * perform the real meat of the operations.
 */
package class RDBBucket : IReadWritable
{
    @disable this();

    /**
     * Return a new RDBBucket with the given prefix
     */
    this(RDBDatabase parentDB, scope Datum prefix)
    {
        this._prefix = prefix;
        this.parentDB = parentDB;
    }

    override void setDatum(scope Datum key, scope Datum value)
    {
        auto dbe = DatabaseEntry(prefix, key);
        parentDB.dbCon.put(dbe.encode(), value);
    }

    override Datum getDatum(scope Datum key)
    {
        auto dbe = DatabaseEntry(prefix, key);
        return parentDB.dbCon.get(dbe.encode());
    }

    pure @property const(Datum) prefix() @safe @nogc nothrow
    {
        return cast(const(Datum)) _prefix;
    }

    /**
     * Return a scope appropriate iterator
     */
    @property override IIterable iterator()
    {
        auto db = parentDB.dbCon;
        auto ro = new ReadOptions();
        ro.prefix_same_as_start = true;
        ro.total_order_seek = false;
        auto it = new rocksdb.Iterator(db, ro);
        auto prefixEntry = DatabaseEntry(prefix, null);
        return new RDBIterator(parentDB, it, prefixEntry.encode());
    }

private:

    Datum _prefix = null;
    RDBDatabase parentDB = null;
}
