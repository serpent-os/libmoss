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

import moss.db.keyvalue;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.driver;
import std.exception : assumeWontThrow;
import std.traits : isFinal;

/**
 * A Database is a managed resource
 */
package final class DatabaseImpl(D) : Database
{

    /**
     * Construct a new DatabaseImpl using the
     * given input URI
     */
    this(string uri) @safe nothrow
    {
        driver = new D();
    }

    ~this()
    {
        /* Ensure correct cleanup */
        driver.close();
        driver.destroy();
    }

    override DatabaseErrorCode view(ViewHandler viewHandler) @safe nothrow const
    {
        viewHandler(this);
        return DatabaseErrorCode.None;
    }

    override DatabaseErrorCode update(UpdateHandler updateHandler) @safe nothrow
    {
        updateHandler(this);
        return DatabaseErrorCode.None;
    }

private:

    Driver driver;
}
