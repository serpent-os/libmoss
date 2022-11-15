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

import std.algorithm : each, map;
import std.conv : to;
import std.exception : enforce;
import std.file : readText;
import std.format : format;
import std.parallelism : totalCPUs;
import std.range : iota;
import std.stdio : File, writeln;
import std.string : split, strip;
import std.typecons : tuple;

private static immutable cpuinfoFile = "/proc/cpuinfo";
/* this is not big.LITTLE friendly (yet) */
private static immutable cpuMaxfrequencyFile = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq";
private static immutable versionFile = "/proc/version";

/**
 * Polled once at startup
 *
 * 64-bit support is assumed a priori
 */
public final class CpuInfo
{
    /**
     * Construct new CpuInfo
     */
    this() @safe
    {
        parseVersionFile();
        parseCpuinfoFile();
        parseCpuMaxfrequencyFile();
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
    pure string[] ISALevels() nothrow @nogc @safe
    {
        return _ISALevels;
    }

    pure const uint numHWThreads() nothrow @nogc @safe
    {
        return _numHWThreads;
    }

private:

    /**
     * Parse /proc/version kernel version file
     */
    void parseVersionFile() @trusted
    {
        auto fi = File(versionFile, "r");
        scope (exit)
        {
            fi.close();
        }
        /* we expect one line */
        if (!fi.eof())
        {
            string line = fi.readln.strip;
            auto fields = line.split;
            enforce(fields.length > 3, format!"%s looks wonky?"(versionFile));
            auto field3 = fields[2];
            _ISA = field3.split(".")[$];
            writeln(_ISA);
        }
    }

    void parseCpuinfoFile() @trusted
    {
        _numHWThreads = totalCPUs();
        /* guard against parseVersionFile not having been run */
        if (_ISA != "unknown")
        {

        }
    }

    void parseCpuMaxfrequencyFile() @trusted
    {
    }

    string _kernel = "Linux version unknown";
    string _ISA = "unknown";
    string[] _ISALevels = ["unknown"];
    string _cpuName = "unknown";
    /* Not sure we need more, but since it's private it can be changed as needed */
    uint _numHWThreads = 0;
    /* big.LITTLE (and equivalents) are false */
    bool _uniformCores = true;
}

/**
 * CPU Frequency information (polled frequently)
 */
public final class CpufreqInfo
{
    /**
     * Construct new CpuInfo
     */
    this() @safe
    {
        numCPU = totalCPUs();
        _frequencies.reserve(totalCPUs);
        _frequencies.length = totalCPUs;

        refresh();
    }

    /**
     * Refresh data
     */
    void refresh() @safe
    {
        iota(0, totalCPUs).map!((i) => tuple!("cpu", "freq")(i,
                readText(format!"/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq"(i))
                .strip.to!double))
            .each!((cpu, freq) => _frequencies[cpu] = freq);
    }

    /**
     * Return the current frequencies
     */
    @property auto frequencies() @safe
    {
        return _frequencies[0 .. numCPU];
    }

    /**
     * This is a bit excessive, but its a 64-bit native datatype
     */
    ulong numCPU = 0;

private:
    double[] _frequencies;
}
