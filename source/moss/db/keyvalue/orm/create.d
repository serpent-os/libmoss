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

            /* Construct metadata bucket */
            auto errMeta = createMetaBucket!modelType(tx);
            if (!errMeta.isNull)
            {
                return err;
            }

            static foreach (field; __traits(allMembers, modelType))
            {
                {
                    /* Public members only */
                    static if (__traits(compiles, __traits(getMember, modelType, field)))
                    {
                        alias fieldType = getFieldType!(modelType, field);
                        static if (isEncodableSlice!fieldType)
                        {
                            /* Can't Index on slices. */
                            static assert(!isFieldIndexed!(modelType, field),
                                    M.stringof ~ "." ~ field
                                    ~ ": Encodable slices cannot be @Indexed");
                        }
                        else static if (isFieldIndexed!(modelType, field))
                        {
                            /* Handle @Indexed buckets */
                            auto e = createIndexBucket!(modelType, field)(tx);
                            if (!e.isNull)
                            {
                                return e;
                            }
                        }
                    }
                }
            }
        }
    }

    return NoDatabaseError;
}

/**
 * Helper to create per-index buckets
 */
private static DatabaseResult createIndexBucket(M, alias F)(scope return Transaction tx) @safe
{
    return tx.createBucketIfNotExists(indexName!(M, F))
        .match!((DatabaseError err) => DatabaseResult(err), (Bucket bk) => NoDatabaseError);
}

/**
 * Helper to create per-model meta bucket
 */
private static DatabaseResult createMetaBucket(M)(scope return Transaction tx) @safe
{
    return tx.createBucketIfNotExists(metaName!M)
        .match!((err) => DatabaseResult(err), (bk) => NoDatabaseError);
}
