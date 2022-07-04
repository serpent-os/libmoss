/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.errors
 *
 * SumType errors for Database
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.errors;

public import std.sumtype;

/**
 * Error code. 0 = good.
 */
public enum DatabaseErrorCode
{
    None = 0,
    UnsupportedDriver,
}

/**
 * "nothrow" encapsulation of errors
 */
public struct DatabaseError
{
    DatabaseErrorCode code;
    string message;
}
