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
import std.string : split;
import std.exception : enforce;
import moss.db.keyvalue.impl;

/**
 * We hide a lot of dirty internals to support multiple driver
 * implementations in an agnostic fashion
 */
public interface Database
{
    public static Database open(in string uri)
    in
    {
        assert(uri !is null, "URI cannot be null");
    }
    do
    {
        /* We need to split this into a URL to validate it.. */
        auto splits = uri.split(":");
        enforce(splits.length > 0, "Database.open(): URI MUST includ the scheme (i.e. rocksdb://");
        auto scheme = splits[0];

        switch (scheme)
        {
        case "memory":
            import moss.db.keyvalue.driver.memory;

            return new DatabaseImpl!MemoryDriver(uri);
        default:
            throw new Exception("onoes: " ~ uri);
        }
    }
}

unittest
{
    auto db = Database.open("memory://memoryDriver");
    assert(db !is null, "Could not open RocksDB database!");
}
