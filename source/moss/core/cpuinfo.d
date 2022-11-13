/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.cpuinfo
 *
 * Access to CPU information via /proc/cpuinfo on Linux
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.core.cpuinfo;

private static immutable cpuinfoFile = "/proc/cpuinfo";
private static immutable versionFile = "/proc/version";

import std.stdio : File;
import std.string : split, strip;
import std.conv : to;

/**
 * 64-bit support is assumed a priori
 */
public final class CpuInfo
{
    /**
     * Construct new CpuInfo
     */
    this() @safe
    {
        refresh();
    }

    /**
     * Instruction Set Architecture
     *
     * Returns: string describing architecture
     */
    pure const string ISA() nothrow @nogc @safe
    {
        return _ISA;
    }

    /**
     * Supported ISA levels for rendering
     *
     * Returns: string array of supported ISA levels
     */
    string[] ISALevels()
    {
        return _ISALevels;
    }

    pure const ubyte numHWThreads() nothrow @nogc @safe
    {
        return _numHWThreads;
    }

    void refresh() @trusted
    {};

private:

    string _ISA = "unknown";
    string[] _ISALevels = ["unknown"];
    string _cpuName = "unknown";
    /* Not sure we need more, but since it's private it can be changed as needed */
    ubyte _numHWThreads = 0;
    /* big.LITTLE (and equivalents) are false */
    bool _uniformCores = true;
}

