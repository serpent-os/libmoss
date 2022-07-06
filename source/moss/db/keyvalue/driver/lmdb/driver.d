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
    override DatabaseResult connect(const(string) uri, DatabaseFlags flags) @safe nothrow
    {
        /* no env dir */
        int cFlags = MDB_NOSUBDIR;

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

        /* Open 0600 connection to the DB */
        rc = () @trusted {
            return mdb_env_open(env, uri.toStringz, cFlags, octal!600);
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
        return new LMDBTransaction(this);
    }

    /**
     * Construct a new LMDB specific RW transaction
     */
    override ExplicitTransaction readWriteTransaction() @safe
    {
        return new LMDBTransaction(this);
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

private:

    /* MDB environment */
    MDB_env* env;
}
