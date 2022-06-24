/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary
 *
 * Module namespace imports.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary;

public import std.stdint : uint32_t;

public import moss.format.binary.archive_header;
public import moss.format.binary.endianness;
public import moss.format.binary.payload;
public import moss.format.binary.reader;
public import moss.format.binary.writer;

/**
 * Current version of the package format that we target.
 */
const uint32_t mossFormatVersionNumber = 1;
