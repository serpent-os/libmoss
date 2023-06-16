/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.endianness
 *
 * Automagically handle endianness conversions.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.endianness;

import std.bitmanip;
import std.stdint;
import std.traits;

@("Test endian conversion") @safe unittest
{
    uint64_t l = 0;
    uint32_t l2 = 0;
    uint16_t l3 = 0;

    assert(autoEndianConvert(l).sizeof == uint64_t.sizeof);
    assert(autoEndianConvert(l2).sizeof == uint32_t.sizeof);
    assert(autoEndianConvert(l3).sizeof == uint16_t.sizeof);
}

/**
 * Convert an integer to the right endian type
 *
 * Params:
 *   v = Value to convert
 */
package auto autoEndianConvert(T)(T v) @safe @nogc nothrow
{
    static union AutoEndianConv(T)
            if (isNumeric!T && !isFloatingPoint!T && !isBoolean!T)
    {
        ubyte[T.sizeof] bytes;
        T value;

        pure this(T v) @safe @nogc nothrow
        {
            value = v;
        }

        /**
        * On little-endian systems, convert to big-endian (network order)
        */
        pragma(inline, true) pure void toNetworkOrder() @safe @nogc nothrow
        {
            version (LittleEndian)
            {
                bytes = nativeToBigEndian(value);
            }
        }

        /**
        * On little-endian systems, convert back to little-endian (host order)
        */
        pragma(inline, true) pure void toHostOrder() @safe @nogc nothrow
        {
            version (LittleEndian)
            {
                value = bigEndianToNative!(T, T.sizeof)(bytes);
            }
        }
    }

    return AutoEndianConv!T(v);
}

/**
 * UDA to assist with translation between endian
 */
struct AutoEndian
{
}

/**
 * Perform conversion (toHostOrder/toNetworkOrder)
 *
 * Params:
 *   T = Type of Thing
 *   v = Thing with members
 */
static void orderHelper(T, string funcer)(ref T v) @safe @nogc nothrow
{
    foreach (member; __traits(allMembers, T))
    {
        static if (__traits(compiles, __traits(getMember, T, member)))
        {
            mixin("import " ~ moduleName!T ~ ";");

            static if (mixin("hasUDA!(" ~ T.stringof ~ "." ~ member ~ ", AutoEndian)"))
            {
                static assert(mixin("!is(typeof(" ~ T.stringof ~ "." ~ member ~ ") == uint8_t)"),
                        "Do not @AutoEndian a uint8_t: " ~ T.stringof ~ "." ~ member);
                static assert(mixin("(" ~ T.stringof ~ "." ~ member ~ ".sizeof != uint8_t.sizeof)"),
                        "Do not @AutoEndian a uint8_t derived enum: " ~ T.stringof ~ "." ~ member);
                mixin("auto e = autoEndianConvert(v." ~ member ~ ");");
                mixin("e." ~ funcer ~ "();");
                mixin("v." ~ member ~ " = cast(typeof(T." ~ member ~ ")) e.value;");
            }
        }
    }
}

/**
 * Convert struct members to host order
 */
pragma(inline, true) public void toHostOrder(T)(ref T v) @safe @nogc nothrow
{
    v.orderHelper!(T, "toHostOrder");
}

/**
 * Convert struct members to network order
 */
pragma(inline, true) public void toNetworkOrder(T)(ref T v) @safe @nogc nothrow
{
    v.orderHelper!(T, "toNetworkOrder");
}
