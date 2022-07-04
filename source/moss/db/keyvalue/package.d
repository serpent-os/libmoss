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

public alias ViewHandler = void delegate(in ReadableView view) @safe nothrow;
public alias UpdateHandler = void delegate(scope WritableView view) @safe nothrow;

public interface ReadableView
{

}

public interface WritableView
{

}

public interface Readable
{
    DatabaseErrorCode view(ViewHandler viewHandler) @safe nothrow;
}

public interface Writable
{
    DatabaseErrorCode update(UpdateHandler updateHandler) @safe nothrow;
}

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
    DatabaseErrorCode connect() @safe
    {
        return DatabaseErrorCode.None;
    }

private:

    string uri;
    Driver driver;
}

@safe unittest
{
    auto db = new Database("memory://memoryDriver");
    auto result = db.connect();
    assert(result == 0);
}
