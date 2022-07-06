/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.driver.lmdb
 *
 * Key Value DB implemented using LMDB
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.driver.lmdb;

public import moss.db.keyvalue.driver;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.interfaces;

import std.conv : octal;
import std.string : toStringz;

import lmdb;

static private string lmdbStr(int rcCode) @trusted nothrow @nogc
{
    import std.string : fromStringz;

    return cast(string) mdb_strerror(rcCode).fromStringz;
}

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
    override Transaction readOnlyTransaction() @safe
    {
        return null;
    }

    /**
     * Construct a new LMDB specific RW transaction
     */
    override Transaction readWriteTransaction() @safe
    {
        return null;
    }

private:

    /* MDB environment */
    MDB_env* env;
}
