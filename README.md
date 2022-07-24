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

## ORM API

The ORM API makes extensive use of `CTFE` (Compile Time Function Execution) and static reflection to provide a minimal-overhead Object-Relational-Mapping system that is compile-time verified. Following a similar path to the Django model design, each struct may be designated as a `@Model` having at least one `@PrimaryKey`.

Instead of trying to jury-rig types, the ORM API relies on `mossEncode` and `mossDecode` overloads to convert string keys and a multitude of value
types into an `immutable(ubyte[])` sequence. Therefore, even custom field
types in a model can be supported by overloading `mossEncode` etc.

## TODO:

 - [ ] Stabilise the API
 - [ ] Full `-preview=dip1000` compliance (in place except for ORM)
 - [ ] Full `-preview=in` compliance
 - [ ] Benchmark and optimize.