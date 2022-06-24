/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.source_definition
 *
 * Defines the notion of a SourceDefinition, which describes the
 * properties of the package, such as name, version etc. (FIXME)
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.source_definition;

public import moss.format.source.schema;
public import std.stdint : uint64_t;

/**
 * Source definition details the root name, version, etc, and where
 * to get sources
 */
struct SourceDefinition
{
    /**
     * The base name of the software package. This should follow both
     * the upstream name and the packaging policies.
     */
    @YamlSchema("name", true) string name;

    /**
     * A version identifier for this particular release of the software.
     * This has no bearing on selections, and is only provided to allow
     * humans to understand the version of software being included.
     */
    @YamlSchema("version", true) string versionIdentifier;

    /**
     * Releases help determine priority of updates for packages of the
     * same origin. Bumping the release number will ensure an update
     * is performed.
     */
    @YamlSchema("release", true) uint64_t release;

    /**
     * All packages MUST set a homepage or package origin.
     * Accountability is key.
     */
    @YamlSchema("homepage", true) string homepage;

    /**
     * Licenses must be set accordingly.
     * We require SPDX identifiers too.
     */
    @YamlSchema("license", true, YamlType.Array) string[] license;
}
