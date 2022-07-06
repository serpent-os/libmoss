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

import cdb = lmdb;

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
    }

    /**
     * Close
     *
     */
    override void close() @safe
    {
    }
}
