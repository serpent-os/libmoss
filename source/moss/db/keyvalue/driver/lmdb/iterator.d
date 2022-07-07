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
import lmdb;

/**
 * LMDB specific implementation of a bucket iterator
 */
package final class LMDBIterator : BucketIterator
{
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
}
