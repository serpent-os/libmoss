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
    this(string uri) @safe nothrow
    {
        /* Init the driver now. Abort if all goes wrong */
        assumeWontThrow(() @trusted {
            driver.refCountedStore.ensureInitialized();
            driver.refCountedPayload.init(uri);
        }());
    }

    ~this()
    {
        /* Ensure correct cleanup */
        driver.close();
        driver.destroy();
    }

    override DatabaseErrorCode view(void delegate(in ReadableView view) @safe nothrow viewHandler) @safe nothrow const
    {
        viewHandler(this);
        return DatabaseErrorCode.None;
    }

    override DatabaseErrorCode update(void delegate(scope WritableView view) @safe nothrow viewHandler) @safe nothrow
    {
        viewHandler(this);
        return DatabaseErrorCode.None;
    }

private:

    alias RCDriver = RefCounted!(DriverImpl, RefCountedAutoInitialize.no);
    alias DriverImpl = D;
    RCDriver driver;
}
