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

module moss.db.keyvalue.driver.lmdb.driver;

public import moss.db.keyvalue.driver;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.interfaces;

import std.conv : octal;
import std.string : toStringz;

import lmdb;

import moss.db.keyvalue.driver.lmdb : lmdbStr;
import moss.db.keyvalue.driver.lmdb.transaction;

import moss.core.ioutil : IOUtil;
import moss.core.ioutil : CError;

/**
 * Implementation using LMDB
 */
public final class LMDBDriver : Driver
{
    /**
     * Open LMDB environment + open from a given path
     *
     * Params:
     *      uri = Resource locator string
     *      flags = Flags that affect opening
     * Returns: A nullable error
     */
    override DatabaseResult connect(const(string) uri, DatabaseFlags flags) @safe
    {
        int cFlags = 0;
        this.flags = flags;
        import std.file : exists;

        if ((flags & DatabaseFlags.CreateIfNotExists) == DatabaseFlags.CreateIfNotExists)
        {
            /* Make the database if it doesn't exist */
            if (!uri.exists)
            {
                auto result = () @trusted {
                    return IOUtil.mkdir(uri, octal!755, true);
                }();
                auto err = result.match!((bool b) => CError.init, (CError err) => err);
                if (err != CError.init)
                {
                    return () @trusted {
                        return DatabaseResult(DatabaseError(DatabaseErrorCode.InternalDriver,
                                cast(string) err.toString));
                    }();
                }
            }
        }

        /* Read-only? */
        if ((flags & DatabaseFlags.ReadOnly) == DatabaseFlags.ReadOnly)
        {
            cFlags |= MDB_RDONLY;
        }

        /* no sync ? */
        if ((flags & DatabaseFlags.DisableSync) == DatabaseFlags.DisableSync)
        {
            cFlags |= MDB_NOSYNC;
        }

        /* Create environment first */
        int rc = () @trusted { return mdb_env_create(&env); }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.ConnectionFailed, lmdbStr(rc)));
        }

        /* Set the map page size */
        enum ulong GiB = 1024 * 1024 * 1024;
        rc = () @trusted { return mdb_env_set_mapsize(env, 8 * GiB); }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.ConnectionFailed, lmdbStr(rc)));
        }

        /* "data", "meta", "bucketMap", "free list" */
        rc = () @trusted { return mdb_env_set_maxdbs(env, 4); }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.InternalDriver, lmdbStr(rc)));
        }

        /* Open 0600 connection to the DB */
        rc = () @trusted {
            return mdb_env_open(env, uri.toStringz, cFlags, octal!644);
        }();
        if (rc != 0)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.ConnectionFailed, lmdbStr(rc)));
        }

        return NoDatabaseError;
    }

    /**
     * Close
     *
     */
    override void close() @safe @nogc nothrow
    {
        if (env is null)
        {
            return;
        }

        () @trusted { mdb_env_close(env); }();
    }

    /**
     * Construct a new LMDB specific RO transaction
     */
    override ExplicitTransaction readOnlyTransaction() @safe
    {
        return new LMDBTransaction(this, false);
    }

    /**
     * Construct a new LMDB specific RW transaction
     */
    override ExplicitTransaction readWriteTransaction() @safe
    {
        return new LMDBTransaction(this, true);
    }

package:

    /**
     * Expose native environment handle
     *
     * Returns: MDB_env pointer
     */
    pragma(inline, true) pure @property MDB_env* environment() @safe @nogc nothrow
    {
        return env;
    }

    /**
     * Expose flags to transactions
     */
    pragma(inline, true) pure @property auto databaseFlags() @safe @nogc nothrow
    {
        return flags;
    }

private:

    /* MDB environment */
    MDB_env* env;
    DatabaseFlags flags;
}
