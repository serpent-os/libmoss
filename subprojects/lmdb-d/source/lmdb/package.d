/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * lmdb
 *
 * Module level imports
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module lmdb;

public import lmdb.binding;
public import lmdb.macros;
public import std.conv : octal;

import std.file : rmdirRecurse, mkdir;
import std.string : toStringz, fromStringz;

unittest
{
    MDB_env* environment = null;
    MDB_txn* txn = null;
    MDB_dbi dbi;

    "testDB".mkdir();

    auto rc = mdb_env_create(&environment);
    assert(rc == 0, mdb_strerror(rc).fromStringz);
    scope (exit)
    {
        mdb_env_close(environment);
        "testDB".rmdirRecurse();
    }

    /* Open env/transaction */
    rc = mdb_env_open(environment, "testDB", MDB_CREATE, octal!600);
    assert(rc == 0, mdb_strerror(rc).fromStringz);
    rc = mdb_txn_begin(environment, null, 0, &txn);
    assert(rc == 0, mdb_strerror(rc).fromStringz);

    /* We want a root-table RW view */
    rc = mdb_dbi_open(txn, null, MDB_CREATE, &dbi);
    assert(rc == 0, mdb_strerror(rc).fromStringz);

    /* Stick key/value pair in */
    MDB_val key = MDB_val("name".length + 1, cast(void*) "name".toStringz);
    MDB_val val = MDB_val("jimothy".length + 1, cast(void*) "jimothy".toStringz);
    rc = mdb_put(txn, dbi, &key, &val, 0);
    assert(rc == 0, mdb_strerror(rc).fromStringz);

    /* Commit + close*/
    rc = mdb_txn_commit(txn);
    assert(rc == 0, mdb_strerror(rc).fromStringz);
    txn = null;

    /* Read only view */
    rc = mdb_txn_begin(environment, null, MDB_RDONLY, &txn);
    assert(rc == 0, mdb_strerror(rc).fromStringz);

    /* Storage for query  */
    MDB_val keyGet = MDB_val("name".length + 1, cast(void*) "name".toStringz);
    MDB_val valFGet = MDB_val(0, null);

    /* Get the value from key */
    assert(rc == 0, mdb_strerror(rc).fromStringz);
    rc = mdb_get(txn, dbi, &key, &valFGet);
    assert(rc == 0, mdb_strerror(rc).fromStringz);

    /* Verify the data */
    auto dd = cast(char*) valFGet.mv_data;
    assert(dd.fromStringz == "jimothy", "not matched");
    mdb_txn_abort(txn);
}
