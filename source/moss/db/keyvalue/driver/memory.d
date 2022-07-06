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

module moss.db.keyvalue.driver.memory;

public import moss.db.keyvalue.driver;
import moss.db.keyvalue.errors;

/**
 * Implementation using an associative array :)
 */
public final class MemoryDriver : Driver
{
    /**
     * Connect
     *
     * Params:
     *      uri = Resource locator string
     */
    override DatabaseResult connect(const(string) uri) @safe
    {
        return NoDatabaseError;
    }

    /**
     * Close
     *
     */
    override void close() @safe
    {
    }
}
