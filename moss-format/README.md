### moss-format

Agnostic format library for package management. Roll your own package manager. Right now we have two main modules, and you can build either as a dependency (`moss-format:binary` or `moss-format:source`).

#### Binary Format (`moss.format.binary`)

The binary archive provides an agnostic streaming system via the `Reader` and `Writer` classes. No default limitations are imposed on the format other than complying with the `Payload` API. In the **default** implementation (i.e. in [boulder](https://gitlab.com/serpent-os/core/boulder)) - the core Payload types are included by default. It is possible to reuse this library for a lightweight, well organised binary package format without using any of the default Payloads.

##### `MetaPayload`

The meta payload is a simple, strongly typed, variable length key value store.

##### `IndexPayload`

The Index payload stores offsets to files within the `ContentPayload`

##### `ContentPayload`

The Content payload is simply a concatenated series of unique files as seen within the package to permit deduplication.

##### `LayoutPayload`

The layout payload consists of encoded entries which define how to apply a file from the `ContentPayload` (or relative links, devices, etc) to the target filesystem.

Together these payloads allow a well defined + structured binary format with automatic support for stream (de)compression, built-in CRC64ISO integrity checks and versioning. In the context of [Serpent OS](https://serpentos.com), our package format is entirely implemented for deeply deduplicated packages & cache stores, with installation routines implemented within `moss`.

The format currently supports `zstd` and `zlib` stream compression, and is completely endian-aware.

####  Source Format (`moss.format.source`)

The source module provides our package recipe support, and is unofficially termed as the `stone.yml` format. It is implemented using a stricter variant of YAML as implemented through rigid parsing via the [`dyaml`](https://dlang-community.github.io/D-YAML/) module. The format is largely inspired by the developers' previous work on the Solus `package.yml` format, and addresses some Serpent OS-specific requirements such as multiple-architecture builds, contextual nesting, etc.

While it is possible to read the YML files without the library, it is highly recommended to do so in order to support a full range of features such as variable expansion and script substitution, as used heavily by [boulder](https://gitlab.com/serpent-os/core/boulder).
