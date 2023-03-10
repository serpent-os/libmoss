/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.logger
 *
 * Add coloured output tailored for a better terminal experience.
 *
 * Authors: Copyright © 2023 Serpent OS Developers
 * License: Zlib
 */
module moss.core.logger;

public import std.experimental.logger;

import std.stdio : stderr;
import std.concurrency : initOnce;
import std.traits;
import std.exception : assumeWontThrow;
import std.string : format;
import std.range : empty;

/**
 * We create our logger with compile time constants
 */
public enum ColorLoggerFlags
{
    /**
     * No flags is no color, no timestamps
     */
    None = 1 << 0,

    /**
     * Enable timestamps in log output
     */
    Timestamps = 1 << 1,

    /**
     * Enable color in log output
     */
    Color = 1 << 2,
}

/**
 * This should be performed in the main routine of a module that
 * wishes to use logging. For now we only set the sharedLog to
 * a new instance of the logger.
 *
 */
public static void configureLogger(ColorLoggerFlags flags = ColorLoggerFlags.Color) @trusted nothrow
{
    __gshared shared(ColorLogger) logger;
    assumeWontThrow(() @trusted {
        sharedLog = initOnce!logger(new shared ColorLogger(flags));
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
     *      loggerFlags = Flags to enable capabilities
     */
    shared this(ColorLoggerFlags loggerFlags = ColorLoggerFlags.Color) @trusted
    {
        super(LogLevel.all);
        this.loggerFlags = loggerFlags;
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
        string resetSequence = "";

        /* Make sure we have a built render string */
        string renderString;
        if ((loggerFlags & ColorLoggerFlags.Color) == ColorLoggerFlags.Color)
        {
            resetSequence = "\x1b[0m";
            renderString = assumeWontThrow(logFormatStrings[payload.logLevel]);
            if (renderString.empty)
            {
                return;
            }
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
        if ((loggerFlags & ColorLoggerFlags.Timestamps) == ColorLoggerFlags.Timestamps)
        {
            timestamp = format!"[%02s:%02s:%02s]"(payload.timestamp.hour,
                    payload.timestamp.minute, payload.timestamp.second);
        }

        /* Emit. */
        stderr.writefln!"%s%s %s%-9s%s %s"(timestamp, fileinfo, renderString,
                level, resetSequence, payload.msg);
    }

private:

    __gshared ColorLoggerFlags loggerFlags = ColorLoggerFlags.Color;
}
