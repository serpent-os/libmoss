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
import moss.db.keyvalue.interfaces;
import std.string : split, format;

/**
 * KeyValue database, driver backed
 */
public final class Database
{
    @disable this();

    invariant ()
    {
        assert(driver !is null);
    }

    /**
     * Open a database for the given URI
     *
     * The scheme portion of the URI is abused to map to an internal
     * driver. So a `rocksdb://` or `memory://` URI is mappped to
     * the correct handling driver. Note that two slashes in the host
     * portion of the scheme are stripped, thus `:///home` points to `/home`.
     *
     * Params:
     *      uri = Resource locator
     */
    static SumType!(Database, DatabaseError) open(string uri) @safe
    {
        auto splits = uri.split(":");
        immutable(string) scheme = splits.length > 1 ? splits[0] : "[unspecified]";
        Driver driver;

        /* Map to the correct driver. */
        switch (scheme)
        {
        case "memory":
            import moss.db.keyvalue.driver.memory : MemoryDriver;

            driver = new MemoryDriver();
            break;
        default:
            driver = null;
        }

        if (driver is null)
        {
            return SumType!(Database, DatabaseError)(DatabaseError(DatabaseErrorCode.UnsupportedDriver,
                    format!"No driver found supporting scheme: '%s'"(scheme)));
        }

        return SumType!(Database, DatabaseError)(new Database(driver));
    }

    /**
     * Access a read-only view of the DB via a scoped lambda
     *
     * Params:
     *      viewDg = Delegate that will be called with a `scope const ref` Transaction
     *
     */
    void view(scope void delegate(in Transaction tx) @safe viewDg) @safe
    {

    }

    /**
     * Access a read-write view of the DB via a scoped lambda.
     *
     * Params:
     *      updateDg = Delegate that will be called with a `scope` Transaction
     */
    void update(scope void delegate(scope Transaction tx) @safe updateDg) @safe
    {

    }

    void close() @safe
    {

    }

private:

    /**
     * Construct a new Database that owns the given driver.
     */
    this(Driver driver) @safe @nogc nothrow
    {
        this.driver = driver;
    }

    string uri;
    Driver driver;
}

@safe unittest
{
    Database db;
    Database.open("memory://memorydriver").match!((d) => db = d,
            (DatabaseError e) => assert(0, e.message));
    scope (exit)
    {
        db.close();
    }
}
