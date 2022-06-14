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

/**
 * This should be performed in the main routine of a module that
 * wishes to use logging. For now we only set the sharedLogger to
 * a new instance of the logger
 */
public static void configureLogging()
{
    auto instance = initOnce!logger(new ColorLogger);
    sharedLog = instance;
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
        immutable(string) resetSequence = "\x1b[0m";
        import std.format : format;

        switch (payload.logLevel)
        {
        case logLevel.warning:
            renderString = "\x1b[1;33m\x1b[1m";
            break;
        case LogLevel.error:
            renderString = "\x1b[1;31m\x1b[1m";
            break;
        case LogLevel.info:
            renderString = "\x1b[1;34m\x1b[1m";
            break;
        case LogLevel.fatal:
            renderString = "\x1b[1;31m\x1b[1m";
            break;
        default:
            renderString = "\x1b[1m";
            break;
        }

        /* Format as a "nice" timestamp. */
        auto timestamp = format!"[%02s:%02s:%02s]"(payload.timestamp.hour,
                payload.timestamp.minute, payload.timestamp.second);

        stderr.writefln!"%s %s%-9s%s %s"(timestamp, renderString, level,
                resetSequence, payload.msg);
    }
}
