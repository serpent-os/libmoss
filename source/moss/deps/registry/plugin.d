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

module moss.deps.registry.plugin;

public import moss.deps.registry.item;
public import moss.deps.dependency;
public import std.typecons : Nullable;

/**
 * A RegistryPlugin is added to the RegistryManager allowing it to load data from pkgIDs
 * if present.
 */
public interface RegistryPlugin
{
    /**
     * Return a set of providers if our flags match up (i.e. Available vs Installed)
     * and the conditionals are met: type and (full) match string.
     */
    RegistryItem[] queryProviders(in ProviderType type, in string matcher,
            ItemFlags flags = ItemFlags.None);

    /**
     * Return information on the given candidate
     */
    ItemInfo info(in string pkgID) const;

    /**
     * Return a registry item for the given ID. Return will be isNull() if
     * the pkgID cannot be located.
     */
    NullableRegistryItem queryID(in string pkgID);

    /**
     * Return the dependencies for a given package ID
     */
    const(Dependency)[] dependencies(in string pkgID) const;

    /**
     * Return the providers for a given package ID
     */
    const(Provider)[] providers(in string pkgID) const;

    /**
     * List all items by filter. This ensures we don't do a slow
     * list of repos when explicitly looking for installed packaages
     */
    const(RegistryItem)[] list(in ItemFlags flags) const;

    /**
     * Request the plugin deallocate any resources
     */
    void close();
}
