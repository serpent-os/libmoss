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

/**
 * Internal type to auto convert uint64
 */
package union autoEndianUint64
{
    ubyte[8] bytes;
    uint64_t value;

    static assert(autoEndianUint64.sizeof == uint64_t.sizeof, "Invalid size for uint64_t");

    pure this(uint64_t v) @safe @nogc nothrow
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
            value = bigEndianToNative!(uint64_t, 8)(bytes);
        }
    }
}

/**
 * Internal type to auto convert uint32
 */
package union autoEndianUint32
{
    ubyte[4] bytes;
    uint32_t value;

    static assert(autoEndianUint32.sizeof == uint32_t.sizeof, "Invalid size for uint32_t");

    pure this(uint32_t v) @safe @nogc nothrow
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
            value = bigEndianToNative!(uint32_t, 4)(bytes);
        }
    }
}

/**
 * Internal type to auto convert uint16
 */
package union autoEndianUint16
{
    ubyte[2] bytes;
    uint16_t value;

    static assert(autoEndianUint16.sizeof == uint16_t.sizeof, "Invalid size for uint16_t");

    pure this(uint16_t v) @safe @nogc nothrow
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
            value = bigEndianToNative!(uint16_t, 2)(bytes);
        }
    }
}

/**
 * UDA to assist with translation between endian
 */
struct AutoEndian
{
}

/**
 * Return the correct endian helper for uint64_t
 */
static pure auto autoEndianConvert(uint64_t v) @safe @nogc nothrow
{
    return autoEndianUint64(v);
}

/**
 * Return the correct endian helper for uint32_t
 */
static pure auto autoEndianConvert(uint32_t v) @safe @nogc nothrow
{
    return autoEndianUint32(v);
}

/**
 * Return the correct endian helper for uint16_t
 */
static pure auto autoEndianConvert(uint16_t v) @safe @nogc nothrow
{
    return autoEndianUint16(v);
}

/**
 * Internal helper to convert between endians
 */
static void orderHelper(T, string funcer)(ref T v) @safe @nogc nothrow
{
    import std.traits : hasUDA, moduleName;

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
