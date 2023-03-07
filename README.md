# zstd-d

[libzstd](https://facebook.github.io/zstd) bindings for the D language.

## Building

zstd-d supports both Meson and Dub.

To build with Dub, run `dub build`.

To build with Meson, run `meson setup build && meson compile -C build`. Should you prefer to build zst-d statically, pass `-Dprefer_static=true` to `meson setup`.

⚠ **Note to macOS 12 users**: if you're encountering linking issues, see [this bug report](https://issues.dlang.org/show_bug.cgi?id=23517).

## Running tests

To run tests with Dub, run `dub test`.

To run tests with Meson, run `meson test -C build`.

## License

Copyright © 2022-2023 Serpent OS Developers

Available under the terms of the [Zlib](https://spdx.org/licenses/Zlib.html).
