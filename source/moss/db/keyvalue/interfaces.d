/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.interfaces
 *
 * API design for the project (inspired heavily by boltdb)
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.interfaces;

import moss.db.keyvalue.errors;

/**
 * Readable sources
 */
public interface Readable
{
    /**
     * Retrieve current value indicated by key
     */
    DatabaseReturn get(in ubyte[] key, out ubyte[] value) @safe;
}

/**
 * Writable targets
 */
public interface Writable
{
    /**
     * Set `key` to `value`
     */
    DatabaseReturn set(in ubyte[] key, in ubyte[] value) @safe;

    /**
     * Remove key / value pair from storage
     */
    DatabaseReturn removeKey(in ubyte[] key) @safe;
}

/**
 * Buckets extend Read/Write functionality into a container
 */
public interface Bucket : Readable, Writable
{
    /**
     * Remove this bucket and all children
     */
    DatabaseReturn remove() @safe;
}

/**
 * Transactions are obtained from the root database.
 */
public interface Transaction : Readable, Writable
{
    /**
     * Retrieve a bucket from the transaction
     * Note that the bucket only persists in the current *scope*
     */
    DatabaseReturn bucket(in ubyte[] prefix, void delegate(scope Bucket) @safe bucketCall) @safe;
}

/**
 * Manual transactions offer more granularity.
 */
public interface ManualTransaction : Transaction
{

    /**
     * Try to commit the transaction
     */
    DatabaseReturn commit() @safe;

    /**
     * Try to rollback the transaction
     */
    DatabaseReturn rollback() @safe;
}

/**
 * Databases support implicit + explicit transactions.
 */
public interface GenericDatabase
{
    /**
     * Access a bucket in the DB
     */
    DatabaseReturn bucket(in ubyte[] prefix, void delegate(scope Bucket) @safe bucketCall) const @safe;

    /**
     * Start read only transaction of the DB
     */
    DatabaseReturn view(void delegate(in Transaction tx) @safe) const @safe;

    /**
     * Start read-write transaction of the DB
     */
    DatabaseReturn update(void delegate(scope Transaction tx) @safe) @safe;

    /**
     * Start a new transaction that is manually controlled.
     */
    ManualTransaction begin() @safe;
}
