/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.build_definition
 *
 * Defines the notion of a BuildDefinition, which describes the steps
 * to produce a moss .stone package.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.build_definition;

public import moss.format.source.schema;

/**
 * A Build Definition provides the relevant steps to complete production
 * of a package. All steps are optional.
 */
public struct BuildDefinition
{
    /**
     * Setup step.
     *
     * These instructions should perform any required setup work such
     * as patching, configuration, etc.
     */
    @YamlSchema("setup") string stepSetup = null;

    /**
     * Build step.
     *
     * These instructions should begin compilation of the source, such
     * as with "make".
     */
    @YamlSchema("build") string stepBuild = null;

    /**
     * Install step.
     *
     * This is the final build step, and should be used to install the
     * files produced by the previous steps into the target "collection"
     * area, ready to be converted into a package.
     */
    @YamlSchema("install") string stepInstall = null;

    /**
     * Check step.
     *
     * We can now ensure consistency of the package by running a test
     * suite before attempting to deploy it to the users.
     */
    @YamlSchema("check") string stepCheck = null;

    /**
     * The workload is executed for Profile Guided Optimisation builds.
     */
    @YamlSchema("workload") string stepWorkload = null;

    /**
     * Build environment.
     *
     * Common variables and instructions to include with each step.
     */
    @YamlSchema("environment") string buildEnvironment = null;

    /**
     * Build dependencies
     *
     * We list build dependencies in a format suitable for consumption
     * by the package manager.
     */
    @YamlSchema("builddeps", false, YamlType.Array) string[] buildDependencies;

    /**
     * Check dependencies
     *
     * Additional dependencies used for the check stage of the build.
     */
    @YamlSchema("checkdeps", false, YamlType.Array) string[] checkDependencies;

    /** Parent definition to permit lookups */
    BuildDefinition* parent = null;

    /**
     * Return the relevant setup step
     */
    string setup() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepSetup != null && node.stepSetup != "(null)" && node.stepSetup != "")
            {
                return node.stepSetup;
            }
            node = node.parent;
        }
        return null;
    }

    /**
     * Return the relevant build step
     */
    string build() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepBuild != null && node.stepBuild != "(null)" && node.stepBuild != "")
            {
                return node.stepBuild;
            }
            node = node.parent;
        }
        return null;
    }

    /**
     * Return the relevant install step
     */
    string install() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepInstall != null && node.stepInstall != "(null)" && node.stepInstall != "")
            {
                return node.stepInstall;
            }
            node = node.parent;
        }
        return null;
    }

    /**
     * Return the relevant check step
     */
    string check() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepCheck != null && node.stepCheck != "(null)" && node.stepCheck != "")
            {
                return node.stepCheck;
            }
            node = node.parent;
        }
        return null;
    }

    /**
     * Return the relevant PGO workload step
     */
    string workload() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepWorkload != null && node.stepWorkload != "(null)" && node.stepWorkload
                    != "")
            {
                return node.stepWorkload;
            }
            node = node.parent;
        }
        return null;
    }

    /**
     * Return the relevant build environment output
     */
    string environment() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.buildEnvironment != null
                    && node.buildEnvironment != "(null)" && node.buildEnvironment != "")
            {
                return node.buildEnvironment;
            }
            node = node.parent;
        }
        return null;
    }
}
