/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.orm.load;
 *
 * Load support for the ORM API
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.orm.load;

public import moss.db.keyvalue.errors;
public import moss.db.keyvalue.interfaces;
public import moss.db.keyvalue.orm.types;

import std.algorithm : map;
import std.array : array;
import std.range : ElementType;
import std.traits;

/**
 * Load an object by the primary key
 *
 * Params:
 *      M = model
 *      V = lookup value type
 *      obj = Object in which to load the return value
 *      tx = Transaction
 *      lookup = Primary key to lookup
 * Returns: non null DatabaseResult if we failed to load it.
 */
public DatabaseResult load(M, V)(scope return out M obj,
        scope const ref Transaction tx, in return V lookup) @safe
        if (isValidModel!M)
{
    obj = M.init;
    import std.conv : to;

    enum searchColumn = getSymbolsByUDA!(M, PrimaryKey)[0].stringof;
    alias searchType = Unconst!(typeof(__traits(getMember, obj, searchColumn)));

    /* Ensure we're checking the key properly! */
    static assert(is(searchType == Unconst!(typeof(lookup))),
            M.stringof ~ ".load(" ~ searchColumn ~ "): Mismatched primaryKey type, expected "
            ~ searchType.stringof ~ ", got " ~ V.stringof);

    /**
     * Perform lookup by primary key.
     */
    M searchObj;
    mixin("searchObj." ~ searchColumn ~ " = lookup;");
    auto bucketID = rowName(searchObj);
    auto bucket = tx.bucket(bucketID);
    if (bucket.isNull)
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                M.stringof ~ ".load(" ~ searchColumn ~ "): Cannot find " ~ to!string(lookup)));
    }

    static foreach (field; __traits(allMembers, M))
    {
        static if (__traits(compiles, __traits(getMember, M, field)))
        {
            {
                alias fieldType = getFieldType!(M, field);
                static if (isEncodableSlice!fieldType && !isFieldIndexed!(M, field))
                {
                    /* Handle slices */
                    immutable name = sliceName!(M, field)(searchObj);
                    auto sliceBucket = tx.bucket(name);
                    if (sliceBucket.isNull)
                    {
                        return DatabaseResult(DatabaseError(DatabaseErrorCode.KeyNotFound,
                                M.stringof ~ ".load(" ~ searchColumn
                                ~ "): Key not found: " ~ field.idup));
                    }
                    /* Map them all back into the slice */
                    auto results = () @trusted {
                        return tx.iterator!(ElementType!fieldType,
                                ushort)(sliceBucket).map!((r) => r.key).array;
                    }();
                    mixin("obj." ~ field ~ " = results;");
                }
                else
                {
                    immutable auto rawData = tx.get(bucket, field.mossEncode);
                    if (rawData is null)
                    {
                        obj = M.init;
                        return DatabaseResult(DatabaseError(DatabaseErrorCode.KeyNotFound,
                                M.stringof ~ ".load(" ~ searchColumn
                                ~ "): Key not found: " ~ field.idup));
                    }
                    mixin("obj." ~ field ~ ".mossDecode(rawData);");
                }
            }
        }
    }

    return NoDatabaseError;
}

/**
 * Load according to a specific index
 *
 * Params:
 *      searchColumn = @Indexed field name
 *      M = Model
 *      V = value type
 *      obj = Storage for the operation
 *      tx = Read-only transaction
 *      indexValue = Unique value to search within the index
 * Returns: Nullable error type
 */
public DatabaseResult load(alias searchColumn, M, V)(scope return out M obj,
        scope const ref Transaction tx, in return V indexValue) @safe
        if (isValidModel!M)
{
    obj = M.init;

    /* Ensure its a thing. */
    static assert(__traits(compiles, __traits(getMember, Unconst!M, searchColumn)),
            M.stringof ~ "." ~ searchColumn ~ ": Search column does not exist");

    /* To access UDAs on each field we have to import it. */
    mixin("import " ~ moduleName!M ~ " : " ~ Unconst!(OriginalType!M).stringof ~ ";");

    /* Make sure its @Indexed */
    static assert(isFieldIndexed!(M, searchColumn),
            M.stringof ~ "." ~ searchColumn ~ ": Not an @Indexed field");

    alias searchType = Unconst!(typeof(__traits(getMember, M, searchColumn)));
    static assert(is(searchType == Unconst!V),
            M.stringof ~ "." ~ searchColumn ~ ": Wrong type for field, got "
            ~ V.stringof ~ ", expected " ~ searchType.stringof);

    auto bucket = tx.bucket(indexName!(M, searchColumn));
    if (bucket.isNull)
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                M.stringof ~ ".load(): Create the model first!"));
    }

    auto res = tx.get(bucket, indexValue.mossEncode);
    if (res is null)
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.KeyNotFound,
                M.stringof ~ ".load(): Cannot find key"));
    }

    enum primaryColumn = getSymbolsByUDA!(M, PrimaryKey)[0].stringof;
    alias primaryType = Unconst!(typeof(__traits(getMember, obj, primaryColumn)));

    primaryType key;
    key.mossDecode(res);
    return obj.load(tx, key);
}
