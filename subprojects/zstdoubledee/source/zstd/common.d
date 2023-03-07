module zstd.common;

import std.format;
import std.stdint;
import std.string;

import zstd.c.symbols;

/**
 * The base class of all zstd exceptions.
 *
 * Functions never return an error code, instead they throw this base
 * class or a child of it.
 */
class ZSTDException : Exception
{
package:

    /**
     * Constructs the object with a custom message.
     */
    this(string msg, string filename = __FILE__, size_t line = __LINE__) @trusted
    {
        super(msg, filename, line);
    }

    /**
     * Construct the object with a zstd error code.
     *
     * The exception message is obtained from [ZSTD_getErrorName].
     */
    this(size_t code, string filename = __FILE__, size_t line = __LINE__) @trusted
    in
    {
        assert(ZSTD_isError(code));
    }
    do
    {
        const auto name = ZSTD_getErrorName(code).fromStringz();
        super("%s (%d)".format(cast(string) name, code), filename, line);
    }

    /**
     * Convenience method to throw this exception in the event code is an error.
     *
     * Wraps [ZSTD_isError].
     */
    static throwIfError(size_t code)
    {
        if (ZSTD_isError(code))
        {
            throw new ZSTDException(code);
        }
    }
}

unittest
{
    bool caught = false;
    try
    {
        throw new ZSTDException("my expected message");
    }
    catch (ZSTDException e)
    {
        caught = true;
        assert(e.msg == "my expected message");
    }
    assert(caught == true, "exception not caught");
}

unittest
{
    import std.exception : assertNotThrown, assertThrown;
    import core.exception : AssertError;

    const auto errCode = ZSTD_compress(null, 0, null, 0, 1);
    immutable auto okCode = 0;
    assertNotThrown(
        new ZSTDException(errCode),
        "%d should be an error code but it's not".format(errCode));
    assertThrown!AssertError(
        new ZSTDException(okCode),
        "%d should not be an error code, but it is".format(okCode));
}

unittest
{
    import std.exception : assertNotThrown, assertThrown;

    const auto errCode = ZSTD_compress(null, 0, null, 0, 1);
    immutable auto okCode = 0;
    assertNotThrown(ZSTDException.throwIfError(okCode));
    assertThrown!ZSTDException(ZSTDException.throwIfError(errCode));
}

/**
 * Defines the efficiency/speed ratio of compression operations.
 * Higher values mean slower but smaller outcome, lower values
 * mean faster but bigger outcome.
 */
alias CompressionLevel = int32_t;
