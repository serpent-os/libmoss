/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.create;
 *
 * Creation support for the ORM API
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.orm.create;

public import moss.db.keyvalue.errors;
public import moss.db.keyvalue.interfaces;
public import moss.db.keyvalue.orm.types;

import std.traits;

/**
 * Create the inital model (primary key buckets etc)
 *
 * Params:
 *      M = Model
 *      tx = Read-write transaction
 * Returns: nullable error
 */
public DatabaseResult createModel(M...)(scope return Transaction tx) @safe
{
    static foreach (modelType; M)
    {
        static assert(isValidModel!modelType);
        {
            /* Handle primary model */
            auto err = tx.createBucketIfNotExists(modelName!modelType)
                .match!((DatabaseError error) => DatabaseResult(error),
                        (Bucket bk) => NoDatabaseError);
            if (!err.isNull)
            {
                return err;
            }

            /* Create all of the indices */
            static foreach (field; getSymbolsByUDA!(modelType, Indexed))
            {
                {
                    auto e = tx.createBucketIfNotExists(indexName!(modelType, field.stringof))
                        .match!((DatabaseError err) => DatabaseResult(err),
                                (Bucket bk) => NoDatabaseError);
                    if (!e.isNull)
                    {
                        return e;
                    }
                }
            }
        }
    }

    return NoDatabaseError;
}
