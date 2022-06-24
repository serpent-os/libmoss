/* SPDX-License-Identifier: Zlib */

/**
 * moss.core.logging
 *
 * Improves logging experience to provide a more normalised terminal
 * experience.
 *
 * Authors: Copyright © 2022 Serpent OS Developers
 * License: Zlib
 */
module moss.core.logging;

public import std.experimental.logger;

import std.stdio : stderr;
import std.concurrency : initOnce;
import std.traits;
import std.exception : assumeWontThrow;
import std.string : format;
import std.range : empty;

/**
 * This should be performed in the main routine of a module that
 * wishes to use logging. For now we only set the sharedLogger to
 * a new instance of the logger.
 *
 */
public static void configureLogging(bool enableTimestamps = false) @safe nothrow
{
    assumeWontThrow(() @trusted {
        sharedLog = initOnce!logger(new ColorLogger(enableTimestamps));
        globalLogLevel = LogLevel.info;
    }());
}

private enum ColourAttr : ubyte
{
    Reset = 0,
    Bright = 1,
    Dim = 2,
    Underscore = 4,
    Blink = 5,
    Reverse = 7,
    Hidden = 8
}

private enum ColourFG : ubyte
{
    Black = 30,
    Red = 31,
    Green = 32,
    Yellow = 33,
    Blue = 34,
    Magenta = 35,
    Cyan = 36,
    White = 37
}

private enum ColourBG : ubyte
{
    Black = 40,
    Red = 41,
    Green = 42,
    Yellow = 43,
    Blue = 44,
    Magenta = 45,
    Cyan = 46,
    White = 47
}

private __gshared immutable string[LogLevel] logFormatStrings;

shared static this()
{
    logFormatStrings = [
        LogLevel.off: null,
        LogLevel.trace: format!"\x1b[%sm"(cast(ubyte) ColourAttr.Dim),
        LogLevel.info: format!"\x1b[%s;%sm"(cast(ubyte) ColourAttr.Bright,
                cast(ubyte) ColourFG.Blue),
        LogLevel.warning: format!"\x1b[%s;%sm"(cast(ubyte) ColourAttr.Bright,
                cast(ubyte) ColourFG.Yellow),
        LogLevel.error: format!"\x1b[%s;%sm"(cast(ubyte) ColourAttr.Bright,
                cast(ubyte) ColourFG.Red),
        LogLevel.critical: format!"\x1b[%s;%s;%sm"(cast(ubyte) ColourAttr.Underscore,
                cast(ubyte) ColourAttr.Bright, cast(ubyte) ColourFG.Red),
        LogLevel.fatal: format!"\x1b[%s;%s;%sm"(cast(ubyte) ColourAttr.Bright,
                cast(ubyte) ColourFG.Black, cast(ubyte) ColourBG.Red)
    ];
    logFormatStrings = logFormatStrings.rehash();
}

/**
 * Maintain the global logger instance
 */
private __gshared ColorLogger logger = null;

/**
 * Simplistic logger that provides colourised output
 *
 * In future we need to rework the ColorLogger into something that
 * has configurable behaviour, i.e. timestamps, colour usage, and
 * label printing.
 */
final class ColorLogger : Logger
{
    /**
     * Construct a new ColorLogger with all messages enabled
     *
     * Params:
     *      timestamps = Enable printing of timestamps
     */
    this(bool timestamps = false) @safe
    {
        super(LogLevel.all);
        _timestamps = timestamps;
    }

    /**
     * Write a new log message to stdout/stderr
     *
     * Params:    payload   The log payload
     */
    override void writeLogMsg(ref LogEntry payload) @trusted
    {
        import std.conv : to;
        import std.string : toUpper;

        string level = to!string(payload.logLevel).toUpper;
        string timestamp = "";
        string fileinfo = "";
        immutable(string) resetSequence = "\x1b[0m";

        /* Make sure we have a built render string */
        auto renderString = assumeWontThrow(logFormatStrings[payload.logLevel]);
        if (renderString.empty)
        {
            return;
        }

        /* Show file information for critical & fatal only */
        switch (payload.logLevel)
        {
        case LogLevel.critical:
        case LogLevel.fatal:
            fileinfo = format!"@[%s:%s] "(payload.file, payload.line);
            break;
        default:
            break;
        }

        /* Use timestamps? */
        if (timestamps)
        {
            timestamp = format!"[%02s:%02s:%02s]"(payload.timestamp.hour,
                    payload.timestamp.minute, payload.timestamp.second);
        }

        /* Emit. */
        stderr.writefln!"%s%s %s%-9s%s %s"(timestamp, fileinfo, renderString,
                level, resetSequence, payload.msg);
    }

    pragma(inline, true) pure @property bool timestamps() @safe @nogc nothrow const
    {
        return _timestamps;
    }

private:

    bool _timestamps;
}
