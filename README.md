# moss-db

A simple set of layers on top of a [LMDB](https://www.symas.com/lmdb) backend for lightning quick key-value storage.
Implements bucket-based storage (collections) with automatic management, and enforces a transactional API inspired heavily by [boltdb](https://github.com/boltdb/bolt).

This is a [D Lang](https://dlang.org/) module to trivially add persistent storage to applications, whether web or console.

### License

Copyright &copy; 2020-2022 [Serpent OS](https://serpentos.com) Developers.

Available under the terms of the [Zlib](https://opensource.org/licenses/Zlib) license.

## Bucket API

The lower level API provided by `moss-db` allows the use of "Buckets", aka collections. These are logical units of organisation that allow an additional level of depth to the key/value storage system. As a deliberable limitation, we only support a maximum depth of **1 bucket**.

This design decision ensures more optimal routes are taken when building reverse indexes, rather than trying to implement a nesting document store.

### Usage example:

```d
auto db = Database.open("lmdb://myDB", DatabaseFlags.CreateIfNotExists).tryMatch!((Database d) => d);

/* Write in a new transaction */
auto err = db.update((scope tx) @safe
{
    return tx.createBucketIfNotExists("bob").match!(
        (DatabaseError err) => DatabaseResult(err),
        (Bucket bk) => tx.set(bucket, "age", 12);
    )
});
assert(err.isNull, err.message);

/* Load things */
int age;
db.view((in tx) @safe
{
    age = tx.get(tx.bucket("bob"), "age");
    return NoDatabaseError;
});

auto err = db.view((in tx) @safe
{
    auto bucket 
});
```

## ORM API

The ORM API makes extensive use of `CTFE` (Compile Time Function Execution) and static reflection to provide a minimal-overhead Object-Relational-Mapping system that is compile-time verified. Following a similar path to the Django model design, each struct may be designated as a `@Model` having at least one `@PrimaryKey`.

Instead of trying to jury-rig types, the ORM API relies on `mossEncode` and `mossDecode` overloads to convert string keys and a multitude of value
types into an `immutable(ubyte[])` sequence. Therefore, even custom field
types in a model can be supported by overloading `mossEncode` etc.

### Usage example

```d
@Model struct User
{
    @PrimaryKey uint id;
    @Indexed string username;
    string[] permissions;
    uid[] groups;
}

@Model struct Group
{
    @PrimaryKey uint id;
    @Indexed string name;
    string[] permissions;
    uid[] users;
}

/* Initialise models */
auto err = db.update((scope tx => tx.createModel!(User, Group));

/* Create a group. */
Group g = Group(1, "users", [ "canView" ]);
auto err = db.update((scope tx => g.save(tx));

/* Create a user ... */
User u = User(1, "bob", "bob@emailprovider.com");
u.permissions = [
    "canEdit",
];
auto err = db.update((scope tx => u.save(tx));

/**
 * Add user to group - complete with error checking
 */
auto addUserToGroup(string username, string groupname) @safe
{
    return db.update((scope tx) @safe
    {
        User findUser;
        Group findGroup;
        {
            /* Find the user */
            auto err = findUser.load!"username"(username);
            if (!err.isNull)
            {
                return err;
            }
        }
        {
            /* Find the group */
            auto err = findGroup.load"name"(groupname);
            if (!err.isNull)
            {
                return err;
            }
        }

        findUser.groups ~= findGroup.id;
        findGroup.users ~= findUser.id;
        {
            auto err = findUser.save(tx);
            if (!err.isNull)
            {
                return err;
            }
        }

        return findGroup.save(tx);
    });
}

/* Demonstrate one-to-many relationships */
db.view((in tx) @safe
{
    User u;
    u.load!"username"(tx, "bob");
    auto groups = u.groups.map!((gid) {
        Group g;
        g.load(tx, gid);
        return g.name;
    }
    logInfo("User %d is in groups %s", u.username, groups.array)
});
```

## TODO:

 - [ ] Stabilise the API
 - [ ] Support *partial* edit and load ORM APIs, i.e. single key
 - [ ] Full `-preview=dip1000` compliance (in place except for ORM)
 - [ ] Full `-preview=in` compliance
 - [ ] Benchmark and optimize.