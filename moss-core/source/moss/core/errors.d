/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.errors
 *
 * Lightweight error handling for moss applications
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.core.errors;

public import std.sumtype;
import std.string : format;

/**
 * An empty struct used as the "None" type when matching
 */
public struct Success
{

}

/**
 * Define the origin of a failure
 */
public struct FailureOrigin
{
    /**
     * What line number did the emission happen
     */
    string fileName;

    /**
     * What source line of code did it happen on?
     */
    uint lineNumber;

    /**
     * Bonus points, function name.
     */
    string functionName;
}

/**
 * A Failure is essentially an Error but we're avoiding namespace
 * clashes
 *
 * Params:
 *      T = Specifier type for the failure
 */
public struct TypedFailure(T)
{
    /**
     * Some specifier like a code for fine grained matching
     */
    immutable(T) specifier;

    /**
     * Usable failure string
     */
    immutable(string) message;

    /**
     * Where the error occurred
     */
    immutable(FailureOrigin) origin;

    /**
     * Representation of the failure
     *
     * Returns: string representation of the failure
     */
    auto toString() @safe const
    {
        return () @trusted {
            debug
            {
                return format!"%s | %s:%s  - %s"((TypedFailure!T).stringof,
                        origin.fileName, origin.lineNumber, message);
            }
            else
            {
                return format!"Error: %s"(message);
            }
        }();
    }
}

/**
 * A primitive failure only carries a message
 */
public alias Failure = TypedFailure!uint;

/**
 * Construct a Failure with the relevant debugging information
 *
 * Params:
 *      message = Usable message
 *      specifier = Code or similar
 *      fileName = The .d file
 *      lineNumber = Where in the .d
 *      functionName = What the D
 * Returns: A TypedFailure!uint
 */
pragma(inline, true) public static Failure fail(in string message, in uint specifier = 0,
        string fileName = __FILE__, int lineNumber = __LINE__, string functionName = __FUNCTION__) @safe
{
    return fail!uint(message, specifier, fileName, lineNumber, functionName);
}

/**
 * Construct a TypedFailure!T with the relevant debugging information
 *
 * Params:
 *      T = Type for the failure to bind to
 *      message = Usable message
 *      specifier = Code or similar
 *      fileName = The .d file
 *      lineNumber = Where in the .d
 *      functionName = What the D
 * Returns: A TypedFailure!uint
 */
pragma(inline, true) public static TypedFailure!T fail(T)(in string message, in T specifier,
        string fileName = __FILE__, int lineNumber = __LINE__, string functionName = __FUNCTION__) @safe
{
    return TypedFailure!T(specifier, message, FailureOrigin(fileName, lineNumber, functionName));
}

/**
 * Define an optional result, which has a success type (i.e. Success) and a failure type.
 *
 * Params:
 *      SuccessType = Operation went ok
 *      FailureType = Operation didn't go ok.
 *
 */
public template Optional(alias SuccessType, alias FailureType)
{
    alias Optional = SumType!(SuccessType, FailureType);
}

version (unittest)
{
    /**
    * Super basic result that either has a success
    * flag or a specific failure.
    */
    private static alias MossResult = Optional!(Success, Failure);

    private static MossResult doThing() @safe
    {
        return cast(MossResult) Success();
    }

    private static MossResult doThing2() @safe
    {
        return cast(MossResult) fail("oh crap");
    }

    private static MossResult doThing3() @safe
    {
        return cast(MossResult) Success();
    }
}

@("Testing of the error handling facilities") @safe unittest
{
    import std.stdio : writefln;

    auto r = fail("oh god the chickens");
    writefln("%s", r);

    doThing.match!((Success _) => writefln("Yay"), _ => writefln("Super crap"));
    doThing2.match!((Failure f) => writefln("Failure: %s", f), (_) {});
}
