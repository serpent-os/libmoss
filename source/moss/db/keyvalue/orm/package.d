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

import std.algorithm : filter, map;
import std.array : array;

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

/**
 * Save the object in the current transaction
 *
 * TODO: Store indices!
 *
 * Params:
 *      M = Model
 *      obj = Model object
 *      tx = Read-write transaction
 * Returns: A nullable error
 */
public DatabaseResult save(M)(scope return ref M obj, scope return Transaction tx) @safe
        if (isValidModel!M)
{
    auto rowID = rowName(obj);
    mixin("auto pkey = obj." ~ getSymbolsByUDA!(M, PrimaryKey)[0].stringof ~ ";");

    /* Ensure the *model bucket* exists */
    immutable auto modelBucket = tx.bucket(modelName!M);
    if (modelBucket.isNull)
    {
        return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                M.stringof ~ ".save(): Create the model first!"));
    }

    /* Stash in the primary index */
    {
        auto err = tx.set(modelBucket, pkey.mossEncode, rowID);
        if (!err.isNull)
        {
            return err;
        }
    }

    /**
     * Now save all of the fields
     */
    return tx.createBucketIfNotExists(rowID)
        .match!((DatabaseError err) => DatabaseResult(err), (Bucket itemBucket) {
            /* Encode all the fields */
            static foreach (field; __traits(allMembers, M))
            {
                static if (__traits(compiles, __traits(getMember, obj, field)))
                {
                    {
                        /* To access UDAs on each field we have to import it. */
                        mixin("import " ~ moduleName!M ~ " : " ~ Unconst!(OriginalType!M)
                            .stringof ~ ";");

                        immutable auto key = field.mossEncode;
                        immutable auto val = __traits(getMember, obj, field).mossEncode;

                        DatabaseResult err = tx.set(itemBucket, key, val);
                        if (!err.isNull)
                        {
                            return err;
                        }

                        /* Is this one indexed? */
                        static if (mixin("getUDAs!(" ~ M.stringof ~ "." ~ field ~ ", Indexed)")
                            .length != 0)
                        {
                            {
                                auto bucket = tx.bucket(indexName!(M, field));
                                if (bucket.isNull)
                                {
                                    return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketNotFound,
                                        M.stringof ~ ".save(): Create the model first!"));
                                }
                                auto e = tx.set(bucket, val, pkey.mossEncode);
                                if (!e.isNull)
                                {
                                    return e;
                                }
                            }
                            pragma(msg, "Adding index for " ~ M.stringof ~ "." ~ field);
                        }
                    }
                }
            }

            return NoDatabaseError;
        });
}

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
public DatabaseResult load(M, V)(scope return  out M obj,
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
        {
            immutable auto rawData = tx.get(bucket, field.mossEncode);
            if (rawData is null)
            {
                obj = M.init;
                return DatabaseResult(DatabaseError(DatabaseErrorCode.KeyNotFound,
                        M.stringof ~ ".load(" ~ searchColumn ~ "): Key not found: " ~ field.idup));
            }
            mixin("obj." ~ field ~ ".mossDecode(rawData);");
        }
    }

    return NoDatabaseError;
}

/**
 * Load according to a specific index
 */
public DatabaseResult load(alias searchColumn, M, V)(scope return  out M obj,
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
    static assert(mixin("getUDAs!(" ~ M.stringof ~ "." ~ searchColumn ~ ", Indexed)")
            .length > 0, M.stringof ~ "." ~ searchColumn ~ ": Not an @Indexed field");

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

/**
 * Types defined only for testing
 */
debug
{
    import std.stdint : uint64_t;

    @Model static struct Animal
    {
        @PrimaryKey string breed;
        bool mostlyFriendly;
    }

    @Model static struct UserAccount
    {
        @PrimaryKey uint64_t id;
        @Indexed string username;
        //Group[] groups;
    }

    @Model static struct Group
    {
        @PrimaryKey uint64_t id;
        // UserAccount[] users;
    }

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

    {
        immutable err = db.update((scope tx) => tx.createModel!Animal());
        assert(err.isNull, err.message);
    }

    /* Try to save a dog. */
    {
        auto dog = Animal("dog", true);
        immutable err = db.update((scope tx) => dog.save(tx));
        assert(err.isNull, err.message);
    }

    /* Load a dog only */
    {
        Animal dog;
        immutable err = db.view((tx) => dog.load(tx, "dog"));
        assert(err.isNull, err.message);
        assert(dog.breed == "dog" && dog.mostlyFriendly, "corrupt puppy");
    }

    /* No chickens! */
    {
        Animal chicken;
        immutable err = db.view((tx) => chicken.load(tx, "chicken"));
        assert(!err.isNull, "look at all those chickens");
    }
}

@("Mock users demo") @safe unittest
{
    import moss.db.keyvalue : Database;
    import std.string : format;

    Database db;
    Database.open("lmdb://ormDB2", DatabaseFlags.CreateIfNotExists)
        .match!((d) => db = d, (DatabaseError e) => assert(0, e.message));
    scope (exit)
    {
        db.close();
        import std.file : rmdirRecurse;

        "ormDB2".rmdirRecurse();
    }

    /* Get our model in place */
    {
        immutable err = db.update((scope tx) => tx.createModel!(UserAccount, Group));
        assert(err.isNull, err.message);
    }

    {
        immutable err = db.update((scope tx) @safe {
            foreach (i; 0 .. 500)
            {
                immutable acct = UserAccount(i, format!"User %d"(i));
                auto err = acct.save(tx);
                if (!err.isNull)
                {
                    return err;
                }
            }
            return NoDatabaseError;
        });
    }

    /* Ensure user 30 exists */
    {
        UserAccount account;
        immutable err = db.view((tx) => account.load(tx, 30UL));
        assert(err.isNull, err.message);
        assert(account.id == 30, "Invalid account number");
        assert(account.username == "User 30", "Invalid username");
    }

    {

        import std.range : take;

        UserAccount[] accounts;
        db.view((in tx) @safe {
            accounts = tx.list!UserAccount
                .filter!((u) => u.id < 30)
                .take(10).array;
            return NoDatabaseError;
        });
        assert(accounts.length == 10);
        debug
        {
            import std.stdio : writeln;

            writeln(accounts);
        }

    }

    /* Try to find the user by username */
    {
        UserAccount user;
        immutable err = db.view((tx) => user.load!"username"(tx, "User 29"));
        assert(err.isNull, err.message);
        assert(user.id == 29, "Corrupt user");
    }
}
