/* SPDX-License-Identifier: Zlib */

/**
 * moss.deps.registry.candidate
 *
 * Defines the notion of a PackageCandidate, which is used as a representation
 * of a virtual package with an internal id, version, human readable name etc.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.registry.candidate;

public import moss.deps.dependency : Dependency, Provider;

public import std.stdint : uint32_t, uint64_t;

/**
 * The PackageCandidate type is used for basic representation of a virtual
 * package in non DB settings
 */
struct PackageCandidate
{
    /**
     * Unique ID for the package candidate within DBs. Internal format
     */
    string id = null;

    /**
     * Real package name, i.e. "nano"
     */
    string name = null;

    /**
     * Software version. Display purposes only.
     */
    string versionID = null;

    /**
     * Release field, increments only.
     */
    uint64_t release = 0;

    /**
     * List of dependencies for the package
     */
    Dependency[] dependencies;

    /**
     * List of providers for the package
     */
    Provider[] providers;
}
