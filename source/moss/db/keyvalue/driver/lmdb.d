/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.driver.memory
 *
 * Memory backed driver (for development ONLY)
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
     * Connect
     *
     * Params:
     *      uri = Resource locator string
     */
    override DatabaseResult connect(const(string) uri, DatabaseFlags flags) @safe nothrow
    {
        int cFlags;

        /* Create */
        if ((flags & DatabaseFlags.CreateIfNotExists) == DatabaseFlags.CreateIfNotExists)
        {
            cFlags |= MDB_CREATE;
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

private:

    /* MDB environment */
    MDB_env* env;
}
