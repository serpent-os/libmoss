/* SPDX-License-Identifier: Zlib */

/**
 * Logging
 *
 * Improves logging experience to provide a more normalised
 * terminal experience.
 *
 * Authors: Copyright © 2022 Serpent OS Developers
 * License: Zlib
 */
module moss.core.logging;

public import std.experimental.logger;

import std.stdio : stderr;
import std.concurrency : initOnce;
import std.traits;

/**
 * This should be performed in the main routine of a module that
 * wishes to use logging. For now we only set the sharedLogger to
 * a new instance of the logger
 */
public static void configureLogging(LogLevel level = LogLevel.all)
{
    auto instance = initOnce!logger(new ColorLogger());
    sharedLog = instance;
    if (level != globalLogLevel())
    {
        /* Ensure that the level is set correctly outside of the first invocation */
        globalLogLevel(level);
    }
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
     */
    this(LogLevel level = LogLevel.all) @safe
    {
        super(level);
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

        string renderString;
        string level = to!string(payload.logLevel).toUpper;
        string timestamp = "";
        string fileinfo = "";
        immutable(string) resetSequence = "\x1b[0m";

        import std.format : format;

        /* Add timestamp and fileinfo if the global log level is trace */
        if (globalLogLevel() == LogLevel.trace)
        {
            timestamp = format!"[%02s:%02s:%02s]"(payload.timestamp.hour,
                    payload.timestamp.minute, payload.timestamp.second);
            fileinfo = format!"(%s:%s)"(payload.file, payload.line);
        }

        switch (payload.logLevel)
        {
        case LogLevel.trace:
            renderString = format!"\x1b[%s;%sm"(cast(ubyte) ColourAttr.Bright,
                    cast(ubyte) ColourFG.Blue);
            break;
        case LogLevel.info:
            renderString = format!"\x1b[%s;%sm"(cast(ubyte) ColourAttr.Bright,
                    cast(ubyte) ColourFG.Green);
            break;
        case logLevel.warning:
            renderString = format!"\x1b[%s;%sm"(cast(ubyte) ColourAttr.Bright,
                    cast(ubyte) ColourFG.Yellow);
            break;
        case LogLevel.error:
            renderString = format!"\x1b[%s;%sm"(cast(ubyte) ColourAttr.Bright,
                    cast(ubyte) ColourFG.Red);
            break;
        case LogLevel.critical:
            renderString = format!"\x1b[%s;%s;%sm"(cast(ubyte) ColourAttr.Underscore,
                    cast(ubyte) ColourAttr.Bright, cast(ubyte) ColourFG.Red);
            break;
        case LogLevel.fatal:
            renderString = format!"\x1b[%s;%s;%sm"(cast(ubyte) ColourAttr.Bright,
                    cast(ubyte) ColourFG.Black, cast(ubyte) ColourBG.Red);
            break;
        default:
            renderString = format!"\x1b[%sm"(cast(ubyte) ColourAttr.Bright);
            break;
        }

        stderr.writefln!"%s%s %s%-9s%s %s"(timestamp, fileinfo, renderString,
                level, resetSequence, payload.msg);
    }

    enum ColourAttr : ubyte
    {
        Reset = 0,
        Bright = 1,
        Dim = 2,
        Underscore = 4,
        Blink = 5,
        Reverse = 7,
        Hidden = 8
    }

    enum ColourFG : ubyte
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

    enum ColourBG : ubyte
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
}
