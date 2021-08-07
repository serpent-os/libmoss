/*
 * This file is part of moss-db.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.db.rocksdb.bucket;

public import moss.db : Datum;
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
