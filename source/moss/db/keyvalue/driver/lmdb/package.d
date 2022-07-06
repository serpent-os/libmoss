/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.driver.lmdb
 *
 * KModule level imports
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.driver.lmdb;

public import moss.db.keyvalue.driver.lmdb.driver;
public import moss.db.keyvalue.driver.lmdb.transaction;

static package string lmdbStr(int rcCode) @trusted nothrow @nogc
{
    import std.string : fromStringz;
    import lmdb : mdb_strerror;

    return cast(string) mdb_strerror(rcCode).fromStringz;
}
