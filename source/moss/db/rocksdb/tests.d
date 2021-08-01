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

/**
 * This module simply contains a batch of unit tests 
 */
module moss.db.rocksdb.tests;

import moss.db.rocksdb;
import std.file : exists;

static private const auto dbLocation = "testDB";

/**
 * Helper to nuke the old DB from the disk
 */
static private void cleanupDB(scope Database db)
{
    db.close();
    import std.file : rmdirRecurse;

    dbLocation.rmdirRecurse();
}

/**
 * Simple open/close operation, ensure DB actually exists
 */
private unittest
{
    auto db = new RDBDatabase(dbLocation, DatabaseMutability.ReadWrite);

    assert(dbLocation.exists, "Database not created");
    scope (exit)
    {
        cleanupDB(db);
    }
}

/**
 * Add 1000 integer values, ensure they exist without iteration
 */
private unittest
{
    auto db = new RDBDatabase(dbLocation, DatabaseMutability.ReadWrite);
    scope (exit)
    {
        cleanupDB(db);
    }

    /**
     * Add all the keys
     */
    foreach (i; 0 .. 1000)
    {
        ubyte[1] keyval = [cast(ubyte) i];
        db.set(keyval, keyval);
    }

    foreach (i; 0 .. 1000)
    {
        ubyte[1] lookupkey = [cast(ubyte) i];
        const ubyte[] ret = db.get(lookupkey);

        assert(ret !is null, "Could not retrieve integer key from database");
        assert(ret.length == 1, "Invalid length integer key value from database");

        assert(ret == lookupkey, "Invalid integer return value from database");
    }
}

/**
 * Make sure buckets work appropriately
 */
private unittest
{
    auto db = new RDBDatabase(dbLocation, DatabaseMutability.ReadWrite);
    scope (exit)
    {
        cleanupDB(db);
    }

    auto bucket = db.bucket(cast(ubyte[]) "customBucket");
    assert(bucket !is null, "Could not retrieve customBucket from database");

    /**
      * Add all the keys to bucket
      */
    foreach (i; 0 .. 10)
    {
        ubyte[1] keyval = [cast(ubyte) i];
        bucket.set(keyval, keyval);
    }

    /**
     * Ensure they exist in the bucket
     */
    foreach (i; 0 .. 10)
    {
        ubyte[1] lookupkey = [cast(ubyte) i];
        const ubyte[] ret = bucket.get(lookupkey);

        assert(ret !is null, "Could not retrieve integer key from bucket");
        assert(ret.length == 1, "Invalid length integer key value from bucket");

        assert(ret == lookupkey, "Invalid integer return value from bucket");

        /**
         * Ensure it doesn't exist in root namespace
         */
        const auto ret2 = db.get(lookupkey);
        assert(ret2 is null, "Should not find bucket key in root namespace");
    }
}

/**
 * Iteration based API test (simple)
 */
private unittest
{
    import std.range : iota;
    import std.algorithm : sum, map;

    auto db = new RDBDatabase(dbLocation, DatabaseMutability.ReadWrite);

    scope (exit)
    {
        cleanupDB(db);
    }

    /**
      * Add all the keys to root
      */
    foreach (i; 0 .. 10)
    {
        ubyte[1] keyval = [cast(ubyte) i];
        db.set(keyval, keyval);
    }

    /**
     * Grab an iterator
     */
    auto it = db.iterator();

    /* Sanity check, make sure we have an iterator implementation */
    assert(it !is null, "Failed to grab iterator from database");
    scope (exit)
    {
        it.destroy();
    }

    static const auto knownTotal = iota(0, 10).sum();

    /* Make sure everything is an int */
    const auto calcTotal = it.map!((t) => cast(int) t.value[0]).sum();
    assert(calcTotal == knownTotal, "Iterator failed to iterate correct values");
}

/**
 * Iteration of multiple buckets
 */
private unittest
{
    import std.algorithm : each, sum, map;
    import std.range : iota;
    import std.string : format;

    auto db = new RDBDatabase(dbLocation, DatabaseMutability.ReadWrite);

    scope (exit)
    {
        cleanupDB(db);
    }

    void populateBucket(uint valueOffset, scope Datum prefix)
    {
        auto ptr = prefix !is null ? db.bucket(prefix) : db;
        assert(ptr !is null, "Could not obtain bucket for population");
        foreach (i; iota(0, 10))
        {
            ptr.set(cast(Datum)[i], cast(Datum)[i + valueOffset]);
        }
    }

    /* Populate root with 0-10 key range */
    populateBucket(0, null);

    /* Populate bucket1 with 0-10 key range value offset 100 */
    populateBucket(100, cast(Datum) "bucket1");

    /* Populate bucket2 with 0-10 key range value offset 200 */
    populateBucket(200, cast(Datum) "bucket2");

    db.close();
    db = new RDBDatabase(dbLocation, DatabaseMutability.ReadWrite);

    /* Check bucket1 */
    static const auto bucket1KnownValue = iota(0, 10).map!((r) => r + 100).sum();
    const auto bucket1CalcValue = db.bucket(cast(Datum) "bucket1")
        .iterator.map!((t) => cast(uint) t.value[0]).sum();
    assert(bucket1KnownValue == bucket1CalcValue,
            "Bucket1 has mismatched iteration values, expected %d, got %d".format(
                bucket1KnownValue, bucket1CalcValue));

    /* Check bucket2 */
    static const auto bucket2KnownValue = iota(0, 10).map!((r) => r + 200).sum();
    const auto bucket2CalcValue = db.bucket(cast(Datum) "bucket2")
        .iterator.map!((t) => cast(uint) t.value[0]).sum();
    assert(bucket2KnownValue == bucket2CalcValue,
            "Bucket2 has mismatched iteration values, expected %d, got %d".format(
                bucket2KnownValue, bucket2CalcValue));

    /* Check root */
    static const auto rootKnownValue = iota(0, 10).sum();
    const auto rootCalcValue = db.iterator.map!((t) => cast(uint) t.value[0]).sum();
    assert(rootKnownValue == rootCalcValue,
            "Root bucket has mismatched iteration values, expected %d, got %d".format(
                rootKnownValue, rootCalcValue));
}
