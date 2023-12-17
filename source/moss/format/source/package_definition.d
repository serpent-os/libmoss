/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.package_definition
 *
 * Allows for overriding detected values in a given package, which is
 * useful when defining sub-packages.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.package_definition;

public import moss.format.source.schema;
import moss.format.source.path_definition;

/**
 * A Package Definition allows overriding of specific values from the
 * root context for a sub package.
 */
struct PackageDefinition
{
    /**
     * The name of the package. This is automatically set by the spec
     * parsing routine.
     */
    string name = null;

    /**
     * A brief summary of the what the package is.
     */
    @YamlSchema("summary") string summary;

    /**
     * A longer description of the package, i.e. its aims, use cases,
     * etc.
     */
    @YamlSchema("description") string description;

    /**
     * A list of other "things" (symbols, names) to depend on for
     * installation to be functionally complete.
     */
    @YamlSchema("rundeps", false, YamlType.Array) string[] runtimeDependencies;

    /**
     * A series of paths that should be included within this subpackage
     * instead of being collected into automatic subpackages or the
     * main package. This overrides automatic collection and allows
     * custom subpackages to be created.
     */
    PathDefinition[] paths;

    /**
     * A list of providers (usually names) that cannot be installed together.
     */
    @YamlSchema("conflicts", false, YamlType.Array) string[] conflicts;
}
