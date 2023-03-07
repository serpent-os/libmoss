/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.driver.lmdb
 *
 * KModule level imports
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.driver.lmdb;

public import moss.db.keyvalue.driver.lmdb.driver;
public import moss.db.keyvalue.driver.lmdb.transaction;

public import lmdb : MDB_val;
public import moss.core.encoding : ImmutableDatum;
public import moss.db.keyvalue.interfaces : Bucket, Entry, EntryType;

import std.stdint : uint16_t;

static package string lmdbStr(int rcCode) @trusted nothrow @nogc
{
    import std.string : fromStringz;
    import lmdb : mdb_strerror;

    return cast(string) mdb_strerror(rcCode).fromStringz;
}

/**
    * Helper to encode a key to its bucket
    */
static package MDB_val encodeKey(in Bucket bucket, in ImmutableDatum key) @safe
{
    uint16_t keyLength = cast(uint16_t) key.length;
    Entry entry = Entry(bucket.identity, keyLength, [0, 0]);
    ubyte[] rawData;
    rawData ~= entry.mossEncode;
    if (keyLength > 0)
    {
        rawData ~= key;
    }

    return () @trusted {
        return MDB_val(cast(size_t) rawData.length, cast(void*)&rawData[0]);
    }();
}
