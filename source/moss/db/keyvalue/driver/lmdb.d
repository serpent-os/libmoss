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

import lmdb;

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
    override void connect(const(string) uri) @safe
    {
        /* Create environment first */
        immutable int rc = () @trusted { return mdb_env_create(&env); }();
        assert(rc == 0);
    }

    /**
     * Close
     *
     */
    override void close() @safe
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
