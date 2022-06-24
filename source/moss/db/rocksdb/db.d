/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.rocksdb.db
 *
 * RocksDB-backed implementation of moss' database interface.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.db.rocksdb.db;

import rocksdb;
import moss.db.rocksdb.bucket;
import moss.db.rocksdb.iterator;
import moss.db.rocksdb.transform;

public import moss.core : Datum;
public import moss.db.interfaces : Database, DatabaseMutability, IReadWritable;

/**
 * RocksDB implementation of the KBDatabase interface
 */
public class RDBDatabase : Database
{

    @disable this();

    /**
     * Construct a new RDBDatabase with the given pathURI and mutability settings
     */
    this(const(string) pathURI, DatabaseMutability mut = DatabaseMutability.ReadOnly)
    {
        super(pathURI, mut);

        /* Organise our options */
        dbOpts = new DBOptions();
        auto fact = new BlockedBasedTableOptions();
        fact.wholeKeyFiltering = false;
        fact.filterPolicy = new BloomFilterPolicy(10);
        dbOpts.blockBasedTableFactory = fact;
        dbOpts.prefixExtractor = new NamespacePrefixTransform();

        final switch (mutability)
        {
        case DatabaseMutability.ReadOnly:
            dbOpts.createIfMissing = false;
            dbOpts.errorIfExists = false;
            break;
        case DatabaseMutability.ReadWrite:
            dbOpts.createIfMissing = true;
            dbOpts.errorIfExists = false;
            break;
        }

        /* Establish the DB connection. TODO: Support read-only connections  */
        _dbCon = new rocksdb.Database(dbOpts, pathURI);
        rootBucket = new RDBBucket(this, null);
    }

    /**
     * Set a key in the root namespace
     */
    pragma(inline, true) override void setDatum(scope Datum key, scope Datum value)
    {
        rootBucket.setDatum(key, value);
    }

    /**
     * Get a value from the root namespace
     */
    pragma(inline, true) override Datum getDatum(scope Datum key)
    {
        return rootBucket.getDatum(key);
    }

    /**
     * Return a subset of the database with an explicit prefix for
     * the purposes of namespacing
     */
    override IReadWritable bucketByDatum(scope Datum prefix)
    {
        import std.algorithm : find;

        auto buckets = nests.find!((b) => b.prefix == prefix);
        if (buckets.length > 0)
        {
            return buckets[0];
        }
        auto bk = new RDBBucket(this, prefix);
        nests ~= bk;
        return bk;
    }

    /**
     * Close (permanently) all connections to RocksDB
     */
    override void close()
    {
        import std.algorithm : each;

        if (dbCon is null)
        {
            return;
        }

        /* Kill iterators */
        liveIterators.each!((it) => it.close());

        nests.each!((n) => n.destroy());
        nests = [];
        rootBucket.destroy();
        rootBucket = null;
        dbCon.close();
        dbCon.destroy();
        _dbCon = null;
    }

    @property override IIterable iterator()
    {
        return rootBucket.iterator;
    }

package:

    /**
     * Return underlying connection pointer
     */
    pragma(inline, true) pure @property rocksdb.Database dbCon() @safe @nogc nothrow
    {
        return _dbCon;
    }

    /**
     * Merge iterator 
     */
    void mergeIterator(RDBIterator it)
    {
        liveIterators ~= it;
    }

    /**
     * Drop an iterator
     */
    void dropIterator(RDBIterator it)
    {
        import std.algorithm : remove;

        liveIterators = liveIterators.remove!((itSeek) => itSeek == it);
        it.close();
        it.destroy();
    }

private:

    RDBBucket rootBucket = null;
    RDBBucket[] nests;
    RDBIterator[] liveIterators = [];

    rocksdb.DBOptions dbOpts;
    rocksdb.Database _dbCon = null;
}
