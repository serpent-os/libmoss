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

module moss.deps.registry.item;

public import moss.deps.registry.plugin : RegistryPlugin;

/**
 * Item flags can be combined so that we have more information on a
 * candidate without having to consult the plugin again.
 */
public enum ItemFlags
{
    None = 1 << 0,
    Available = 1 << 1,
    Installed = 1 << 2,
}

/**
 * Each item in the registry is associated with a specific plugin
 * and a unique ID per the origin plugin
 */
public struct RegistryItem
{
    /**
     * Unique package ID
     */
    immutable(string) pkgID;

    /**
     * Origin plugin
     */
    RegistryPlugin plugin;

    /**
     * Return plugin specific dependencies for this item
     */
    pragma(inline, true) @property auto dependencies() const
    {
        return plugin.dependencies(pkgID);
    }

    /**
     * Return plugin specific providers for this item
     */
    pragma(inline, true) @property auto providers() const
    {
        return plugin.providers(pkgID);
    }

    /**
     * Return the flags for this item
     */
    pragma(inline, true) pure @property ItemFlags flags() @safe @nogc nothrow const
    {
        return _flags;
    }

    /**
     * Returns true if the candidate is available
     */
    pragma(inline, true) pure @property bool available() @safe @nogc nothrow const
    {
        return (_flags & ItemFlags.Available) == ItemFlags.Available;
    }

    /**
     * Returns true if the candidate is installed
     */
    pragma(inline, true) pure @property bool installed() @safe @nogc nothrow const
    {
        return (_flags & ItemFlags.Installed) == ItemFlags.Installed;
    }

package:

    ItemFlags _flags = ItemFlags.None;
}
