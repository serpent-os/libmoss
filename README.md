### moss-format

This repository contains the D Modules required by [moss] and [boulder]
to read and write the binary and source formats, respectively.

#### `moss.format.source`

The source module requires `dyyaml` and is capable of parsing a `stone.yml`
file. The `stone.yml` file uses a very strict approach to parsing, and provides
a declarative, structured approach to building distribution packages from source.

Our `stone.yml` format is hugely inspired by the Solus `package.yml` format,
with some extra multi-arch considerations and tweaks.

To read a `stone.yml` file, you should **always** use this library, as it also
applies a schema to the source files. Additionally, script parsing is not possible
without the `ScriptBuilder` type in this repository.

#### `moss.format.binary`

The binary module requires `zstd` and may support more compression methods in
future. It is a low level API to read and write the binary format required by
Moss's `.stone` packages.

The format is designed to be self deduplicating, with multiple payloads defined
per file. Each payload can be compressed, and has built-in CRC64 checks. No part
of the format is plain text and requires special handling to read + write.

At minimum we require 4 payloads:

#####  Index

The Index payload contains metadata on each entry in the Content payload, such
as the size + offset, and the unique hash key.

##### Content

The Content payload contains a huge binary lump, which is simply every **unique,
regular file** within the package. It is only addressable via the Index payload.

##### Layout

The Layout payload is similar to a `%files` list. It contains the filesystem
**layout**, including symlink targets, permissions, etc. Regular files are referenced
via their unique hash key, meaning that multiple Layout entries can reference the
same Content, permitting deduplication

#### Meta

The Meta payload contains all metadata on a package, and supports well defined
key **types** and **tags**. These keys are binary encoded, like the rest of the
package, and have required information such as the name or version of the package.
