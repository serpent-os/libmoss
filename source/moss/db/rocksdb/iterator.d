/*
 * This file is part of moss.
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

module moss.db.rocksdb.iterator;

public import moss.db.interfaces;
public import rocksdb.iterator;

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
    this(rocksdb.Iterator iter)
    {
        this.iter = iter;
        setHead();
    }

public:

    /**
     * Disable default constructor
     */
    @disable this();

    ~this()
    {
        this.iter.close();
        this.iter = null;
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

    DatabaseEntryPair cur;
    rocksdb.Iterator iter;

}
