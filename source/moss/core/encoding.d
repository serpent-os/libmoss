/* SPDX-License-Identifier: Zlib */

/**
 * Encoding
 *
 * Moss packages use extensive binary encoding of types of ubytes.
 * Within the context of any moss package, a Datum is some encoded data
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */
module moss.core.encoding;

import std.traits : isFloatingPoint, isIntegral, isNumeric, isBoolean;

public alias Datum = ubyte[];

/**
 * Convenience alias to make our intentions on mutability clearer
 */
public alias ImmutableDatum = immutable(Datum);

/**
 * Helper to determine if a type can be encoded correctly for moss packsges
 *
 * It must implement the "mossEncode()" function, which must in turn return
 * a "ImmutableDatum" (immutable(ubyte[])) value.
 */
auto isMossEncodable(T)()
{
    static if (is(typeof({ T val = void; return val.mossEncode(); }()) E == ImmutableDatum))
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
auto isMossDecodable(T)()
{
    /* Ensure we have a usable interface, i.e. ".mossDecode(scope ImmutableDatum)" */
    static if (is(typeof({
                T val = void;
                ImmutableDatum inp = cast(ImmutableDatum) null;
                static assert(is(typeof(val.mossDecode(inp)) == void),
                "isMossEncodable(): Return type should be void");
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
    return "" ~ T.stringof ~ " is not encodable. Implement the mossEncode() interface";
}

/**
 * Helper to build the correct debug string when failing to find the correct
 * decoder interface
 */
auto stringifyNonDecodableType(T)()
{
    return "" ~ T.stringof ~ " is not decodable. Implement the mossDecode() interface";
}

/**
 * Automatically encode string to C string with nul terminator
 */
pure public ImmutableDatum mossEncode(T)(in T s) if (is(T == string))
{
    import std.string : toStringz;
    import core.stdc.string : strlen;

    auto stringC = s.toStringz;
    /* '+ 1' because nul terminator extends string length by 1 */
    return cast(ImmutableDatum) stringC[0 .. strlen(stringC) + 1];
}

/**
 * Automatically encode all non floating point numericals to big endian representation
 * when they're more than one byte in size
 */
pure public ImmutableDatum mossEncode(T)(in T i)
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

/**
 * Automatically convert a stored nul-terminated string into a valid D string
 */
pure void mossDecode(T)(out T dest, in ImmutableDatum rawBytes) if (is(T == string))
{
    import std.string : fromStringz;
    import std.exception : enforce;

    dest = (cast(string) fromStringz(cast(char*) rawBytes.ptr)).dup;
}

/**
 * Automatically decode all non floating point numericals from big endian representation
 * when they're more than one byte in size.
 */
pure void mossDecode(T)(out T dest, in ImmutableDatum rawBytes)
        if (!isFloatingPoint!T && (isNumeric!T || isBoolean!T))
{
    import std.bitmanip : bigEndianToNative;
    import std.exception : enforce;

    enforce(T.sizeof == rawBytes.length, "mossDecode!" ~ T.stringof ~ ": Decoding wrong value type");

    static if (T.sizeof > 1)
    {
        dest = bigEndianToNative!(T, T.sizeof)(cast(Datum) rawBytes[0 .. T.sizeof]);
    }
    else
    {
        dest = cast(T) rawBytes[0];
    }
}
