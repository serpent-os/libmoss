/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.registry.plugin
 *
 * Defines the notion of a registry plugin, which can be added to the
 * registry manager.
 *
 * Registry plugins are responsible for knowing how to talk to specific
 * backends hosting package info.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.registry.plugin;

public import moss.core.fetchcontext;
public import moss.deps.registry.item;
public import moss.deps.dependency;
public import std.typecons : Nullable;

@trusted:

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
     * Request that the item is fetched from its location into a storage
     * medium.
     */
    Job fetchItem(in string pkgID);

    /**
     * Request the plugin deallocate any resources
     */
    void close();
}
