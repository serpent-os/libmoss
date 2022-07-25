/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.orm.list;
 *
 * List support for the ORM API
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.orm.list;

public import moss.db.keyvalue.errors;
public import moss.db.keyvalue.interfaces;
public import moss.db.keyvalue.orm.types;

import std.traits;
import std.algorithm : map;
import moss.db.keyvalue.orm.load;

/**
 * List all items by model, without filtering to a specific index
 *
 * Params:
 *      M = Model
 *      tx = read-only transaction
 * Returns: a (mapped) range of all items in the model
 */
public auto list(M)(scope const ref Transaction tx) @safe if (isValidModel!M)
{
    /* Grab the search type.. */
    static immutable(M) obj;
    enum searchColumn = getSymbolsByUDA!(M, PrimaryKey)[0].stringof;
    alias searchType = Unconst!(typeof(__traits(getMember, obj, searchColumn)));

    auto bucket = tx.bucket(modelName!M);
    assert(!bucket.isNull);
    return tx.iterator(bucket).map!((t) {
        searchType key;
        key.mossDecode(t.entry.key);
        M val;
        auto err = val.load(tx, key);
        assert(err.isNull);
        return val;
    });
}
