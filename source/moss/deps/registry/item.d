/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.registry.item
 *
 * Defines a useful abstraction layer for registry plugins, so items
 * in a collection can be queried in a generic manner with implementation
 * specific details handled by the corresponding plugin.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.registry.item;

public import moss.deps.registry.plugin : RegistryPlugin;
public import moss.deps.registry.job;
public import std.stdint : uint64_t;
public import std.typecons : Nullable;
public import std.range : isInputRange;
import std.array : array;
import std.algorithm : multiSort, SwapStrategy, map;

@trusted:

/**
 * Given an input range of items, sort them by various
 * predicates:
 *
 *  plugin.priority
 *  item.releaseNumber
 *  item.buildRelease (soon)
 */
public auto sortedRegistryItems(R)(R items) if (isInputRange!R)
{
    static struct Comparator
    {
        string pkgID;
        uint64_t sourceRelease;
        uint64_t buildRelease;
        uint64_t pluginPriority;
        RegistryPlugin plugin;
        ItemFlags flags;
    }

    auto cmp = items.map!((i) {
        ItemInfo inf = i.info();
        return Comparator(i.pkgID, inf.releaseNumber, 0, i.plugin.priority, i.plugin, i.flags);
    }).array();
    cmp.multiSort!("a.pluginPriority > b.pluginPriority", "a.sourceRelease > b.sourceRelease",
            "a.buildRelease > b.buildRelease", SwapStrategy.unstable);
    return cmp.map!((c) => RegistryItem(c.pkgID, c.plugin, c.flags));
}

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
 * ItemInfo describes the absolute basic metadata of a package
 */
public struct ItemInfo
{
    immutable(string) name = null;
    immutable(string) summary = null;
    immutable(string) description = null;
    immutable(uint64_t) releaseNumber = 0;
    immutable(string) versionID = null;
    immutable(string) homepage = null;
    immutable(string)[] licenses = null;
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
     * Return information on the given item
     */
    pragma(inline, true) @property auto info() const
    {
        return plugin.info(pkgID);
    }

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

    /** 
     * Try to fetch this item
     */
    pragma(inline, true) Job fetch()
    {
        return plugin.fetchItem(pkgID);
    }

    /**
     * Return true if both items are equal
     */
    bool opEquals()(auto ref const RegistryItem other) const
    {
        return other.pkgID == pkgID && other.plugin == plugin;
    }

    /**
     * Compare two items
     */
    int opCmp(ref const RegistryItem other) const
    {
        if (this.pkgID > other.pkgID)
        {
            return 1;
        }
        else if (this.pkgID < other.pkgID)
        {
            return -1;
        }
        if (this.plugin != other.plugin)
        {
            immutable auto otherID = other.plugin.stringof;
            immutable auto thisID = this.plugin.stringof;
            if (otherID < thisID)
            {
                return 1;
            }
            else if (otherID > thisID)
            {
                return -1;
            }
        }
        return 0;
    }

    /**
     * Return the hash code
     */
    ulong toHash() @safe nothrow const
    {
        return typeid(string).getHash(&pkgID);
    }

package:

    ItemFlags _flags = ItemFlags.None;
}

/**
 * Forcibly define the return type of the API to a nullable without run
 * time cost.
 */
public alias NullableRegistryItem = Nullable!(RegistryItem, RegistryItem.init);
