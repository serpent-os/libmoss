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

import moss.db.keyvalue : Database;
import moss.db.keyvalue.driver;
import std.typecons : RefCounted, RefCountedAutoInitialize;

/**
 * A Database is a managed resource
 */
package final class DatabaseImpl(D) : Database
{

    static assert(isDriver!D, D.stringof ~ " does not seem to be a valid driver");

    /**
     * Construct a new DatabaseImpl using the
     * given input URI
     */
    this(string uri)
    {
        /* Init the driver now */
        driver.refCountedStore.ensureInitialized();
        driver.refCountedPayload.init(uri);
    }

    ~this()
    {
        /* Ensure correct cleanup */
        driver.close();
        driver.destroy();
    }

private:

    alias RCDriver = RefCounted!(DriverImpl, RefCountedAutoInitialize.no);
    alias DriverImpl = D;
    RCDriver driver;
}
