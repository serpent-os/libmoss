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
import moss.core.encoding;

public import std.typecons : Nullable;

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
        case "lmdb":
            import moss.db.keyvalue.driver.lmdb : LMDBDriver;

            driver = new LMDBDriver();
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
     */
    Nullable!(DatabaseError, DatabaseError.init) view(
            scope void delegate(in Transaction tx) @safe viewDg) @safe
    {
        return Nullable!(DatabaseError, DatabaseError.init)(DatabaseError(
                DatabaseErrorCode.Unimplemented, ".view() not yet implemented"));
    }

    /**
     * Access a read-write view of the DB via a scoped lambda.
     *
     * Params:
     *      updateDg = Delegate that will be called with a `scope` Transaction
     */
    Nullable!(DatabaseError, DatabaseError.init) update(
            scope void delegate(scope Transaction tx) @safe updateDg) @safe
    {
        return Nullable!(DatabaseError, DatabaseError.init)(DatabaseError(
                DatabaseErrorCode.Unimplemented, ".view() not yet implemented"));
    }

    /**
     * Permanently close this connection
     */
    void close() @safe
    {
        driver.close();
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
    Database.open("lmdb://myDB").match!((d) => db = d, (DatabaseError e) => assert(0, e.message));
    scope (exit)
    {
        db.close();
    }

    bool didUpdate = false;
    bool didView = false;

    /**
     * Add entries for validation
     */
    auto err = db.update((scope tx) @safe {
        import std.string : representation;

        /* TODO: Use mossEncode */
        /* Ensure rocksdb will not match 1 against 1, 1 */
        auto bk = tx.bucket([1]);
        auto bk2 = tx.bucket([1, 1]);

        tx.set(bk, "name".representation, "john".representation);
        tx.set(bk2, "name".representation, "not-john".representation);
        didUpdate = true;
    });
    assert(err.isNull, "error in update");
    assert(didUpdate, "Update lambda not run");

    auto err2 = db.view((in tx) @safe {
        import std.string : representation;

        auto bk = tx.bucket([1]);
        auto bk2 = tx.bucket([1, 1]);

        auto val1 = tx.get(bk, "name".representation);
        assert(val1 == "john".representation);
        auto val2 = tx.get(bk, "name".representation);
        assert(val2 == "not-john".representation);
        didView = true;
    });
    assert(err2.isNull, "error in view");
    assert(didView, "View lambda not run");
}
