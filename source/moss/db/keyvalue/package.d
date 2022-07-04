/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue package
 *
 * Module namespace imports.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue;
import moss.db.keyvalue.driver;
import moss.db.keyvalue.errors;

/**
 * KeyValue database, driver backed
 */
public final class Database
{
    @disable this();

    invariant ()
    {
        assert(uri !is null);
    }

    /**
     * Construct new Database from the given URI
     */
    this(const(string) uri) @safe @nogc nothrow
    {
        this.uri = uri;
    }

    /**
     * Connect the driver to the database
     */
    DatabaseResult connect() @safe
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.UnsupportedDriver, "onoes"));
    }

private:

    string uri;
    Driver driver;
}

@safe unittest
{
    auto db = new Database("memory://memoryDriver");
    auto result = db.connect();
    assert(result.isNull, result.get.message);
}
