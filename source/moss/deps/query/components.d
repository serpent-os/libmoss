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

module moss.deps.query.components;

public import std.stdint : uint32_t, uint64_t;
public import serpent.ecs.component;

/**
 * Store the "pkgID" at runtime
 */
@serpentComponent public struct IDComponent
{
    /**
     * The real package ID
     */
    string id = null;
}

/**
 * Store the package name at runtime
 */
@serpentComponent public struct NameComponent
{
    /**
     * Display name for a package
     */
    string name = null;
}

/**
 * Store the package version at runtime
 */
@serpentComponent public struct VersionComponent
{
    /**
     * Version identifier string for a package
     */
    string versionID = null;
}

/**
 * Store the package release at runtime
 */
@serpentComponent public struct ReleaseComponent
{
    /**
     * Used internally to bump candidate priority
     */
    uint64_t release = 0;
}

/**
 * Each package is assigned a Vertex ID atomically
 * to simplify dependency resolution. We assign these
 * dynamically upon load of a package.
 */
@serpentComponent public struct VertexComponent
{
    /**
     * 32-bit vertex ID
     */
    uint32_t vertexID = 0;
}
