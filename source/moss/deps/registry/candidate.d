/*
 * This file is part of moss-deps.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
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
