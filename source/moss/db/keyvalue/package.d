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
import std.string : startsWith;

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
    static SumType!(Database, DatabaseError) open(string uri,
            DatabaseFlags flags = DatabaseFlags.None) @safe
    {
        auto splits = uri.split("://");
        immutable(string) scheme = splits.length > 1 ? splits[0] : "[unspecified]";
        Driver driver;

        if (splits.length < 2 || uri.length < scheme.length + 4)
        {
            return SumType!(Database, DatabaseError)(DatabaseError(DatabaseErrorCode.UnsupportedDriver,
                    "Unsupported scheme URI: Missing \":\" split"));
        }

        /* Initialise with the remainder, minus any // */
        auto remainder = uri[splits[0].length + 3 .. $];

        /* Map to the correct driver. */
        switch (scheme)
        {
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

        /* Try to connect now */
        auto err = driver.connect(remainder, flags);
        if (!err.isNull)
        {
            return SumType!(Database, DatabaseError)(err.get);
        }

        return SumType!(Database, DatabaseError)(new Database(driver));
    }

    /**
     * Access a read-only view of the DB via a scoped lambda
     *
     * Params:
     *      viewDg = Delegate that will be called with a `scope const ref` Transaction
     * Returns: potentially null error
     */
    DatabaseResult view(scope Nullable!(DatabaseError,
            DatabaseError.init) delegate(in Transaction tx) @safe viewDg) @safe
    {
        auto tx = driver.readOnlyTransaction();
        assert(tx !is null, "Driver returned NULL RO Transaction");
        auto ret = tx.reset();
        if (!ret.isNull)
        {
            return ret;
        }
        ret = viewDg(tx);
        tx.drop();
        return ret;
    }

    /**
     * Access a read-write view of the DB via a scoped lambda.
     *
     * Params:
     *      updateDg = Delegate that will be called with a `scope` Transaction
     * Returns: Potentially null error
     */
    DatabaseResult update(scope Nullable!(DatabaseError,
            DatabaseError.init) delegate(scope Transaction tx) @safe updateDg) @safe
    {
        auto tx = driver.readWriteTransaction();
        assert(tx !is null, "Driver returned NULL RW Transaction");
        auto ret = tx.reset();
        if (!ret.isNull)
        {
            return ret;
        }
        ret = updateDg(tx);
        if (!ret.isNull)
        {
            tx.drop();
            return ret;
        }
        return tx.commit();
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

@("Fairly standard unittest") @safe unittest
{
    Database db;
    Database.open("lmdb://myDB", DatabaseFlags.CreateIfNotExists)
        .match!((d) => db = d, (DatabaseError e) => assert(0, e.message));
    scope (exit)
    {
        db.close();
    }

    bool didUpdate;
    bool didView;

    /**
     * Add entries for validation
     */
    import std.datetime.stopwatch;

    auto w = StopWatch(AutoStart.yes);
    immutable err = db.update((scope tx) @safe {
        import std.string : representation;

        auto bk = tx.bucket([1]);
        auto bk2 = tx.bucket([1, 1]);

        tx.set(bk, "name", "john");
        tx.set(bk, "name2", "jimothy");
        tx.set(bk2, "name", "not-john");
        tx.set(bk2, "name2", "not-jimothy");
        didUpdate = true;

        auto bk3 = tx.bucket("numbers");
        for (int i = 0; i < 100_000; i++)
        {
            tx.set(bk3, i, i);
        }
        return NoDatabaseError;
    });
    debug
    {
        import std.stdio : writeln;

        writeln(w.peek);
    }
    assert(err.isNull, err.get.message);
    assert(didUpdate, "Update lambda not run");

    immutable err2 = db.view((in tx) @safe {
        import std.string : representation;

        auto bk = tx.bucket([1]);
        auto bk2 = tx.bucket([1, 1]);
        auto bk3 = tx.bucket("numbers");

        string val1 = tx.get!(string, string)(bk, "name");
        assert(val1 == "john", "not john");
        string val2 = tx.get!(string, string)(bk2, "name");
        assert(val2 == "not-john", "Not not-john");
        didView = true;

        debug
        {
            import std.stdio : writefln;

            foreach (entry, val; tx.iterator(bk3))
            {
                int keyName;
                int value;
                string bucket;
                keyName.mossDecode(entry.key);
                value.mossDecode(val);
                bucket.mossDecode(entry.prefix);
                writefln("[%s] %s = %s", bucket, keyName, value);
            }
        }

        return NoDatabaseError;
    });
    assert(err2.isNull, err.get.message);
    assert(didView, "View lambda not run");

    /* Delete the numbers bucket */
    immutable err3 = db.update((scope tx) @safe {
        return tx.removeBucket(tx.bucket("numbers"));
    });

    immutable err4 = db.view((in tx) @safe {
        auto bk = tx.bucket([1]);
        auto bk2 = tx.bucket([1, 1]);

        string val1 = tx.get!(string, string)(bk, "name");
        assert(val1 == "john", "not john");
        string val2 = tx.get!(string, string)(bk2, "name");
        assert(val2 == "not-john", "Not not-john");

        return NoDatabaseError;
    });
    assert(err3.isNull);
}
