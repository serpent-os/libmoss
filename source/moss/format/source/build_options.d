/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.build_options
 *
 * Defines build options such as which compiler to use and
 * which optimisations to enable (or disable).
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.build_options;

public import moss.format.source.schema;

/**
 * The TuningSelectionType indicates whether we're explicitly
 * enabling, disabling, or enabling and setting to a specific value
 */
final enum TuningSelectionType
{
    Enable = 0,
    Disable = 1,
    Config = 2,
}

/**
 * A TuningSelection corresponds to a TuningGroup
 */
struct TuningSelection
{
    /** Name of the tuning group */
    string name;

    /**
     * Type of the Tuning Selection
     */
    TuningSelectionType type = TuningSelectionType.Enable;

    /**
     * Optional configuration value
     */
    string configValue = null;
}

/**
 * A set of Build Options set global build configurations, such as the
 * toolchain to be used, what flags to use, etc.
 */
struct BuildOptions
{
    /**
     * The toolchain defaults to LLVM, but can be changed if required
     * to the GNU toolchain, including GCC + binutils.
     */
    @YamlSchema("toolchain", false, YamlType.Single, ["gnu", "llvm"]) string toolchain = "llvm";

    /**
     * Context Sensitive Profile Guided Optimisation
     *
     * Turning this on will result in a multiple stage profiling build of the
     * project and execution of the workload, in the hopes of a finer tuned
     * profile data set
     */
    @YamlSchema("cspgo") bool cspgo = false;

    /**
     * Sample Profile Guided Optimisation
     *
     * When enabling samplepgo, parts of the code not run during workload will
     * no longer be optimized for size. This is handy when you have an important
     * workload to tune, but has low coverage overall.
     */
    @YamlSchema("samplepgo") bool samplepgo = false;

    /**
     * Whether to strip ELF files to eliminate unneeded code and reduce file
     * size
     */
    @YamlSchema("strip") bool strip = true;

    /**
     * Enable networking for the build
     */
    @YamlSchema("networking") bool networking = false;

    /**
     * Compress man pages
     */
    @YamlSchema("compressman") bool compressman = false;

    /**
     * A set of tuning selections to apply. Constructed at runtime through
     * parsing
     */
    TuningSelection[] tuneSelections = [];

    /**
     * Return true if the tuning selection is present
     */
    pure bool hasTuningSelection(string name) @safe
    {
        foreach (ref sel; tuneSelections)
        {
            if (sel.name == name)
            {
                return true;
            }
        }
        return false;
    }
}
