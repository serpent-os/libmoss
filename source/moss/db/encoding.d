/*
 * This file is part of moss-db.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.db.encoding;

import std.traits : isFloatingPoint, isIntegral, isNumeric, isBoolean;

public import moss.db : Datum;

/**
 * Simply for ease of writing.
 */
alias ImmutableDatum = immutable(Datum);

/**
 * Helper to determine if a type can be encoded correctly for moss-db
 *
 * It must implement the "mossdbEncode()" function, which must in turn return
 * a "Datum" (ubyte[]) value.
 */
auto isMossDbEncodable(T)()
{
    static if (is(typeof({ T val = void; return val.mossdbEncode(); }()) E == ImmutableDatum))
    {
        return true;
    }
    else
    {
        return false;
    }
}

/**
 * Is the input type decodable?
 */
auto isMossDbDecodable(T)()
{
    /* Ensure we have a usable interface, i.e. ".mossDbDecode(scope ImmutableDatum)" */
    static if (is(typeof({
                T val = void;
                ImmutableDatum inp = cast(ImmutableDatum) null;
                static assert(is(typeof(val.mossdbDecode(inp)) == T),
                "isMossDbEncodable(): Return type should be " ~ T.stringof);
            })))
    {
        return true;
    }
    else
    {
        return false;
    }
}

/**
 * Helper to build the correct debug string when failing to find the correct
 * encoder interface.
 */
auto stringifyNonEncodableType(T)()
{
    return "" ~ T.stringof ~ " is not moss-db encodable. Implement the mossdbEncode() interface";
}

/**
 * Helper to build the correct debug string when failing to find the correct
 * decoder interface
 */
auto stringifyNonDecodableType(T)()
{
    return "" ~ T.stringof ~ " is not moss-db decodable. Implement the mossdbDecode() interface";
}

/**
 * A DbResult is returned from any get() query, but the internal value may not
 * actually be set to anything useful, thus we include a "found" flag for simplistic
 * matching.
 */
struct DbResult(V)
{
    /**
     * Value field is set to the value retrieved from the database
     */
    V value = V.init;

    /**
     * Found is set to true if the get query was successful
     */
    bool found = false;
}

/**
 * Automatically encode string to C string with nul terminator
 */
pure ImmutableDatum mossdbEncode(T)(in T s) if (is(T == string))
{
    import std.string : toStringz;
    import core.stdc.string : strlen;

    auto stringC = s.toStringz;
    return cast(ImmutableDatum) stringC[0 .. strlen(stringC)];
}

/**
 * Automatically encode all non floating point numericals to big endian representation
 * when they're more than one byte in size
 */
pure ImmutableDatum mossdbEncode(T)(in T i)
        if (!isFloatingPoint!T && (isNumeric!T || isBoolean!T))
{
    import std.bitmanip : nativeToBigEndian;

    /* Any multibyte value must be endian encoded */
    static if (T.sizeof > 1)
    {
        return nativeToBigEndian(i).dup;
    }
    else
    {
        return [i];
    }
}
