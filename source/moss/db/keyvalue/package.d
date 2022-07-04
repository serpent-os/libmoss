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
import std.string : split, format;
import std.exception : enforce;
import moss.db.keyvalue.impl;
import moss.db.keyvalue.errors;

/**
 * We hide a lot of dirty internals to support multiple driver
 * implementations in an agnostic fashion
 */
public interface Database
{
    /**
     * Open a database from the given URI
     */
    public static SumType!(Database, DatabaseError) open(in string uri) @safe
    in
    {
        assert(uri !is null, "URI cannot be null");
    }
    do
    {
        Database newDatabase = null;
        string scheme = "(unspecified)";

        /* We need to split this into a URL to validate it.. */
        auto splits = uri.split(":");
        if (splits.length < 1)
        {
            goto no_db;
        }
        scheme = splits[0];

        switch (scheme)
        {
        case "memory":
            import moss.db.keyvalue.driver.memory;

            newDatabase = new DatabaseImpl!MemoryDriver(uri);
            break;
        default:
            newDatabase = null;
        }

    no_db:
        if (newDatabase !is null)
        {
            return SumType!(Database, DatabaseError)(newDatabase);
        }
        return SumType!(Database, DatabaseError)(DatabaseError(DatabaseErrorCode.UnsupportedDriver,
                format!"No drivers found to match scheme '%s'"(scheme)));
    }
}

unittest
{
    auto dbResult = Database.open("memory://memoryDriver");
    Database db = dbResult.tryMatch!((Database db) => db);
}
