/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.sizing
 *
 * Sane formatting of sizes using 1024-based numbers
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.core.sizing;

import std.algorithm : max, min;
import std.math : floor, log, pow;
import std.string : format;

private static immutable suffixes = ["B", "KiB", "MiB", "GiB", "TiB"];
private static immutable ulong suffixN = cast(ulong)((cast(long) suffixes.length) - 1);
private static immutable unitSize = log(1024);

/**
 * A FormattedSize encapsulates the suffix and power-reduced
 * bytes to permit pretty printing.
 */
public struct FormattedSize
{
    /**
     * Number of bytes by power
     */
    double numUnits;

    /**
     * A suffix such as "MiB"
     */
    string suffix;

    /**
     * Basic emission of the formatted size
     *
     * Returns: newly allocated string
     */
    auto toString() @safe const
    {
        return format!"%.2f %s"(numUnits, suffix);
    }
}

/**
 * Format some input size in real units
 *
 * Params:
 *      inp = Double precision size
 * Returns: String formatted size
 */
pure FormattedSize formattedSize(scope const ref double inp) @safe @nogc nothrow
{
    immutable bytes = max(inp, 0);
    immutable power = min(floor((bytes > 0 ? log(bytes) : 0) / unitSize), suffixN);
    return FormattedSize(bytes / pow(1024, power), suffixes[cast(ulong) power]);
}

/**
 * Default pretty print of size (12 characters wide including suffix)
 *
 * Example:
 * "      100  B"
 * "    1,023  B"
 * "    1.00 KiB"
 * "  999.99 KiB"
 * "    1.00 MiB"
 *     (...)
 * "  999.99 TiB"
 * "9,999.99 TiB"
 *
 * Params:
 *      inp = Double precision size
 * Returns: String representation of this FormattedSize
 */
pure auto formattedSizePadding(scope const ref double inp) @safe
{
    immutable formatted = formattedSize(inp);
    if (formatted.suffix != "B")
    {
        /* ensure that very large sizes have enough room */
        return format!"%7,.2f %-3s"(formatted.numUnits, formatted.suffix);
    }
    else
    {
        /* match up bytes nicely without a dot separator */
        return format!"%8,.0f %2s"(formatted.numUnits, formatted.suffix);
    }
}
