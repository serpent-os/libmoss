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

/**
 * Implementation using an associative array :)
 */
public struct MemoryDriver
{
    /* no copies pls */
    @disable this(MemoryDriver other);

    /**
     * noop
     */
    void init(in string uri)
    {
    }

    /**
     * noop
     */
    void close()
    {
    }
}
