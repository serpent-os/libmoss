/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.orm
 *
 * Compile time ORM support for moss-db
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.orm;

public import moss.db.keyvalue.errors;
public import moss.db.keyvalue.interfaces;
public import moss.db.keyvalue.orm.types;

/**
 * Save the object in the current transaction
 *
 * TODO: Store indices!
 *
 * Params:
 *      M = Model
 *      obj = Model object
 *      tx = Read-write transaction
 * Returns: A DatabaseResult sumtype, check for errors
 */
public DatabaseResult save(M)(scope return ref M obj, scope return Transaction tx) @safe
        if (isValidModel!M)
{
    auto rowID = rowName(obj);

    /* Ensure the *model bucket* exists */
    immutable auto modelBucket = tx.bucket(modelName!M);
    if (modelBucket.isNull)
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                M.stringof ~ ".save(): Create the model first!"));
    }

    /**
     * Now save all of the fields
     */
    return tx.createBucketIfNotExists(rowID)
        .match!((DatabaseError err) => DatabaseResult(err), (Bucket itemBucket) {
            /* Encode all the fields */
            static foreach (field; __traits(allMembers, M))
            {
                {
                    immutable auto key = field.mossEncode;
                    immutable auto val = __traits(getMember, obj, field).mossEncode;

                    DatabaseResult err = tx.set(itemBucket, key, val);
                    if (!err.isNull)
                    {
                        return err;
                    }
                }
            }

            return NoDatabaseError;
        });
}

@("Basic type testing") @safe unittest
{
    @Model static struct User
    {
        @PrimaryKey int id;
        string username;
    }

    immutable auto one = User(2, "bobby");

    static assert(isValidModel!User, "User should be a valid model");
    static assert(modelName!User == "users", "Invalid model name, got: " ~ modelName!User);
    immutable auto expRow = [46, 117, 115, 101, 114, 46, 0, 0, 0, 0, 2];
    assert(rowName(one) == expRow);
}

@("Basic unit testing..") @safe unittest
{
    import moss.db.keyvalue : Database;

    Database db;
    Database.open("lmdb://ormDB", DatabaseFlags.CreateIfNotExists)
        .match!((d) => db = d, (DatabaseError e) => assert(0, e.message));
    scope (exit)
    {
        db.close();
        import std.file : rmdirRecurse;

        "ormDB".rmdirRecurse();
    }

    @Model static struct Animal
    {
        @PrimaryKey string breed;
        bool mostlyFriendly;
    }

    /* Try to save a user. */
    auto dog = Animal("dog", true);
    auto err = db.update((scope tx) @safe { return dog.save(tx); });
    assert(err.isNull, err.message);
}
