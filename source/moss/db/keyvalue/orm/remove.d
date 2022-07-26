/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.remove;
 *
 * Removal support for the ORM API
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.orm.remove;

public import moss.db.keyvalue.errors;
public import moss.db.keyvalue.interfaces;
public import moss.db.keyvalue.orm.types;

import std.traits;

/**
 * Remove a single model from the database
 *
 * Params:
 *      M = Model
 *      inputObj = Input object to remove
 *      tx = Valid read-write transaction
 */
public DatabaseResult remove(M)(scope return const ref M inputObj, scope return Transaction tx) @safe
        if (isValidModel!M)
{
    immutable rowID = rowName(inputObj);
    auto content = tx.bucket(rowID);

    if (content.isNull)
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                M.stringof ~ ".remove(): Item not found"));
    }

    /* Ensure the *model bucket* exists */
    auto modelBucket = tx.bucket(modelName!M);
    if (modelBucket.isNull)
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                M.stringof ~ ".remove(): Create the model first!"));
    }

    /* Remove the row. */
    mixin("auto pkey = inputObj." ~ getSymbolsByUDA!(M, PrimaryKey)[0].stringof ~ ";");
    {
        auto err = tx.remove(modelBucket, pkey.mossEncode);
        if (!err.isNull)
        {
            return err;
        }
    }

    /* Find all keys that have special subbuckets */
    static foreach (field; __traits(allMembers, M))
    {
        static if (__traits(compiles, __traits(getMember, M, field)))
        {
            {
                alias fieldType = getFieldType!(M, field);
                static if (isEncodableSlice!fieldType && !isFieldIndexed!(M, field))
                {
                    /* Remove slice bucket */
                    auto mdk = tx.bucket(sliceName!(M, field)(inputObj));
                    if (mdk.isNull)
                    {
                        return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                                M.stringof ~ ".remove(): Create the model first!"));
                    }
                    auto err = tx.removeBucket(mdk);
                    if (!err.isNull)
                    {
                        return err;
                    }
                }
                else static if (isFieldIndexed!(M, field))
                {
                    /* Remove indexed bucket mapping */
                    auto mdk = tx.bucket(indexName!(M, field));
                    if (mdk.isNull)
                    {
                        return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                                M.stringof ~ ".remove(): Create the model first!"));
                    }
                    /* Need DB stored index value, not whatever was in the input object */
                    immutable oldIndexValue = tx.get(content, field.mossEncode);
                    if (oldIndexValue !is null)
                    {
                        auto err = tx.remove(mdk, oldIndexValue);
                        if (!err.isNull)
                        {
                            return err;
                        }
                    }
                }
            }
        }
    }

    /* Remove the model-instance bucket. */
    return tx.removeBucket(content);
}

/**
 * Completely purge the model from the database.
 *
 * Params:
 *      M = Model
 *      tx = Read-write transaction
 * Returns: Nullable error type
 */
public DatabaseResult removeAll(M)(scope return Transaction tx) @safe
        if (isValidModel!M)
{
    /* Ensure the *model bucket* exists */
    auto modelBucket = tx.bucket(modelName!M);
    if (modelBucket.isNull)
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                M.stringof ~ ".removeAll(): Create the model first!"));
    }

    /* Remove each entry so that the slice buckets etc are wiped. */
    foreach (item; tx.iterator(modelBucket))
    {
        Unconst!M searchObj;
        /* Decode the search object */
        mixin("searchObj." ~ getSymbolsByUDA!(M,
                PrimaryKey)[0].stringof ~ ".mossDecode(item.entry.key);");
        auto instance = tx.bucket(rowName(searchObj));
        if (instance.isNull)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                    M.stringof ~ ".remove(): Create the model first!"));
        }
        static foreach (field; __traits(allMembers, M))
        {
            static if (__traits(compiles, __traits(getMember, M, field)))
            {
                {
                    alias fieldType = getFieldType!(M, field);
                    static if (isEncodableSlice!fieldType && !isFieldIndexed!(M, field))
                    {
                        /* Remove the slice bucket */
                        auto bk = tx.bucket(sliceName!(M, field)(searchObj));
                        if (bk.isNull)
                        {
                            return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                                    M.stringof ~ ".removeAll(): Create the model first!"));
                        }
                        auto err = tx.removeBucket(bk);
                        if (!err.isNull)
                        {
                            return err;
                        }
                    }
                }
            }
        }

        /* Remove the search object bucket itself */
        auto err = tx.removeBucket(instance);
        if (!err.isNull)
        {
            return err;
        }
    }

    /* Remove all index buckets globally */
    static foreach (field; getSymbolsByUDA!(M, Indexed))
    {
        static if (__traits(compiles, __traits(getMember, M, field.stringof)))
        {
            static if (isFieldIndexed!(M, field.stringof))
            {
                auto bk = tx.bucket(indexName!(M, field.stringof));
                if (bk.isNull)
                {
                    return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                            M.stringof ~ ".remove(): Create the model first!"));
                }
                auto err = tx.removeBucket(bk);
                if (!err.isNull)
                {
                    return err;
                }
            }
        }
    }

    {
        auto metabucket = tx.bucket(metaName!M);
        if (metabucket.isNull)
        {
            return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                    M.stringof ~ ".remove(): Create the model first!"));
        }

        /* Goodbye meta bucket */
        auto errMeta = tx.removeBucket(metabucket);
        if (!errMeta.isNull)
        {
            return errMeta;
        }
    }

    /* Goodbye global model */
    return tx.removeBucket(modelBucket);
}
