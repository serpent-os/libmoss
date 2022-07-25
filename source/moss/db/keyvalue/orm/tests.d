/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.orm.tests
 *
 * unit tests
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.orm.tests;

import moss.db.keyvalue;
import moss.db.keyvalue.orm;
import std.algorithm : filter;
import std.array : array;

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
        string[] permissions;
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
                immutable acct = UserAccount(i, format!"User %d"(i), i == 3
                    ? ["canEat(chickens)", "canView(chickens"] : [
                        "canView(chickens)"
                    ]);
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
