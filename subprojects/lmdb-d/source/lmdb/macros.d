/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * lmdb
 *
 * Module level imports
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module lmdb.macros;

import std.string : format;

/**
 * Missing helper from the macro conversion
 */
pragma(inline, true) pure public static auto MDB_VERSTR(int a, int b, int c, string d) @safe
{
    import std.string : format;

    return format!"LMDB %d.%d.%d (%s)"(a, b, c, d);
}
