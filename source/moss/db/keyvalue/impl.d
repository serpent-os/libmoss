/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue package
 *
 * High level implementation of Database
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.impl;

/**
 * A Database is a managed resource
 */
package final class DatabaseImpl(D) : Database
{

    /**
     * Construct a new DatabaseImpl using the
     * given input URI
     */
    this(string uri)
    {
    }

private:

    alias DriverImpl = D;
    DriverImpl driver;
}
