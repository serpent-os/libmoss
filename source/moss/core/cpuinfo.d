/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.cpuinfo
 *
 * Access to CPU information via /proc/cpuinfo and to
 * kernel information via /proc/version on Linux
 *
 * TODO: Actually parse ISA instead of hardcoding it to x86_64
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.core.cpuinfo;

import std.algorithm : canFind, each, fold, map, sort;
import std.conv : to;
import std.exception : enforce;
import std.file : readText;
import std.format : format;
import std.parallelism : totalCPUs;
import std.range : iota;
import std.regex;
import std.stdio : File, writeln;
import std.string : split, strip;
import std.typecons : tuple;

private static immutable cpuinfoFile = "/proc/cpuinfo";
private static immutable versionFile = "/proc/version";

/* Note that 'pni' is 'prescott new instructions' aka SSE3 */
private static immutable _x86_64_v2 = [
    "cx16", "lahf_lm", "popcnt", "pni", "ssse3", "sse4_1", "sse4_2"
];

/* lzcnt is part of abm, osxsave is xsave (CBR4:18) */
private static immutable _x86_64_v3 = [
    "abm", "avx", "avx2", "bmi1", "bmi2", "f16c", "fma", "movbe", "xsave"
];

/* Serpent OS x86_64-v3 extended instruction set profile for improved performance */
private static immutable _x86_64_v3x = [
    "aes", "fsgsbase", "pclmulqdq", "rdrand", "xsaveopt"
];

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
        parseISA();
        parseVersionFile();
        parseCpuinfoFile();
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

    /**
     * CPU model name
     */
    pure const string modelName() nothrow @nogc @safe
    {
        return _modelName;
    }

    /**
     * Useful string output for number of cores/hwthreads
     */
    pure const string numCoresThreads() @safe
    {
        return format!"%dc / %dt"(_numCores, _numHWThreads);
    }

    /**
     * Does this CPU support the x86_64-v2 psABI?
     */
    const bool x86_64_v2() @safe
    {
        auto supported = _x86_64_v2.map!(s => canFind(_cpuFlags, s));
        return supported.fold!((a, b) => a && b);
    }

    /**
     * Does this CPU support the x86_64-v3 psABI?
     *
     * Note: This function does not check for x86_64-v2 psABI support
     */
    pure const bool x86_64_v3() @safe
    {
        auto supported = _x86_64_v3.map!(s => canFind(_cpuFlags, s));
        return supported.fold!((a, b) => a && b);
    }

    /**
     * Does this CPU support the x86_64-v3 psABI + select  psABI?
     *
     * Note: This function does not check for x86_64-v2 nor x86_64-v3 psABI support
     */
    pure const bool x86_64_v3x() @safe
    {
        auto supported = _x86_64_v3x.map!(s => canFind(_cpuFlags, s));
        return supported.fold!((a, b) => a && b);
    }

private:

    /**
     * Parse ISA from machine property in utsname struct from uname(2) syscall
     *
     * TODO: Actually parse the ISA! (we just hardcode to "x86_64" atm)
     */
    void parseISA() @trusted
    {
        _ISA = "x86_64";
    }

    /**
     * Parse /proc/version kernel version file
     */
    void parseVersionFile() @trusted
    {
        auto buffer = readText(versionFile);
        /* we expect a single line */
        if (buffer)
        {
            string _kernel = buffer.strip;
        }

    }

    /**
     * Parse select fields in /proc/cpuinfo
     */
    void parseCpuinfoFile() @trusted
    {
        /* If we can't parse /proc/cpuinfo, bailing with an exception is ok */
        auto buffer = readText(cpuinfoFile);

        /* Find first 'model name' occurence */
        auto modelNameRegex = ctRegex!r"model name\s+:\s+(.*)\n";
        auto m = matchFirst(buffer, modelNameRegex);
        enforce(m.captures[1], format!"CPU model name not listed in %s?"(cpuinfoFile));
        _modelName = m.captures[1].strip;

        /* Find first 'cpu cores' occurence */
        auto numCoresRegex = ctRegex!r"cpu cores\s+:\s+(.*)\n";
        m = matchFirst(buffer, numCoresRegex);
        enforce(m.captures[1],
                format!"Number of physical CPU cores not listed in %s?"(cpuinfoFile));
        _numCores = m.captures[1].strip.to!uint;

        /* Find first 'siblings' occurence */
        auto numHWThreadsRegex = ctRegex!r"siblings\s+:\s+(.*)\n";
        m = matchFirst(buffer, numHWThreadsRegex);
        enforce(m.captures[1], format!"Number of CPU H/W threads not listed in %s?"(cpuinfoFile));
        _numHWThreads = m.captures[1].strip.to!uint;

        /* Find first 'flags' occurence */
        auto cpuFlagsRegex = ctRegex!r"flags\s+:\s+(.*)\n";
        m = matchFirst(buffer, cpuFlagsRegex);
        enforce(m.captures[1], format!"CPU flags not listed in %s?"(cpuinfoFile));
        _cpuFlags = m.captures[1].strip.split;
        _cpuFlags.sort;

        /* parseISA() is run from the constructor */
        if (_ISA != "unknown")
        {
            _ISALevels ~= _ISA;

            if (_ISA == "x86_64" && x86_64_v2)
            {
                _ISALevels ~= "x86_64-v2";
                if (x86_64_v3)
                {
                    _ISALevels ~= "x86_64-v3";
                    if (x86_64_v3x)
                    {
                        _ISALevels ~= "x86_64-v3x";
                    }
                }
            }
        }
    }

    string _ISA = "unknown";
    string[] _ISALevels = [];
    string[] _cpuFlags = [];
    string _kernel = "Linux version unknown";
    string _modelName = "unknown";
    uint _numCores = 0;
    uint _numHWThreads = 0;
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
