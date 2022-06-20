/* SPDX-License-Identifier: Zlib */

/**
 * moss.db.rocksdb.iterator
 *
 * An implementation of the IIterable moss database interface for RocksDB.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.db.rocksdb.iterator;

public import moss.db.interfaces;
public import rocksdb.iterator;

import moss.db.rocksdb.db : RDBDatabase;

/**
 * A concrete implementation of IIterable for RocksDB
 */
package class RDBIterator : IIterable
{
    override bool empty()
    {
        return !iter.valid();
    }

    override DatabaseEntryPair front()
    {
        return cur;
    }

    override void popFront()
    {
        iter.next();
        setHead();
    }

    /**
     * Construct a new Iterator wrapping the internal iterator types
     */
    this(RDBDatabase parentDB, rocksdb.Iterator iter, in Datum prefix)
    {
        this.parentDB = parentDB;
        this.iter = iter;
        this.prefix = cast(Datum) prefix;

        /* Wind to the start of the prefix */
        if (prefix !is null && prefix.length > 0)
        {
            iter.seek(prefix);
        }

        setHead();
        this.parentDB.mergeIterator(this);
    }

public:

    /**
     * Disable default constructor
     */
    @disable this();

    ~this()
    {
        if (parentDB is null)
        {
            return;
        }
        parentDB.dropIterator(this);
    }

    /**
     * Close the iterator resource
     * In some instances, this is done lazily.
     */
    void close()
    {
        if (this.iter !is null)
        {
            this.iter.close();
            this.iter = null;
            this.parentDB = null;
        }
    }

private:

    void setHead()
    {
        if (!iter.valid)
        {
            return;
        }

        auto key = iter.key();
        DatabaseEntryPair pair;
        pair.entry.decode(key);
        pair.value = iter.value();
        cur = pair;
    }

    RDBDatabase parentDB = null;
    DatabaseEntryPair cur;
    rocksdb.Iterator iter;
    Datum prefix;

}
