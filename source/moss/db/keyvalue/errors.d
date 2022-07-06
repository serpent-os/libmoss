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
public import std.stdint : uint8_t;
public import std.typecons : Nullable;

/**
 * Error code. 0 = good.
 */
public enum DatabaseErrorCode : uint8_t
{
    None = 0,
    UnsupportedDriver,
    Unimplemented,
}

/**
 * "nothrow" encapsulation of errors
 */
public struct DatabaseError
{
    /**
     * Encountered error code.
     */
    DatabaseErrorCode code;

    /**
     * Error message, if any
     */
    string message;

    /**
     * Return our error string in hooman form
     */
    pure string toString() const @safe @nogc nothrow
    {
        return message;
    }
}

public alias DatabaseResult = Nullable!(DatabaseError, DatabaseError.init);
/**
 * Returned when we have no error
 */
public enum NoDatabaseError = DatabaseResult(DatabaseError.init);
