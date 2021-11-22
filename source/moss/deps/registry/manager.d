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

module moss.deps.registry.manager;

public import moss.deps.registry.plugin;

import std.algorithm : each, filter, joiner, map;

/**
 * Encapsulation of multiple underlying "query plugins"
 */
public final class RegistryManager
{
    /**
     * Add a plugin to the RegistryManager
     */
    void addPlugin(RegistryPlugin plugin)
    {
        plugins ~= plugin;
    }

    /**
     * Remove an existing plugin from this manager
     */
    void removePlugin(RegistryPlugin plugin)
    {
        import std.algorithm : remove;

        plugins = plugins.remove!((s) => s == plugin);
    }

    /**
     * Return all PackageCandidates by provider
     */
    auto byProvider(in ProviderType type, const(string) provider)
    {
        return plugins.map!((s) => s.queryProviders(type, provider)).joiner;
    }

    /**
     * Return all PackageCandidates by Name
     */
    pragma(inline, true) auto byName(const(string) pkgName)
    {
        return byProvider(ProviderType.PackageName, pkgName);
    }

    /**
     * Return all package candidates matching the given ID
     */
    pragma(inline, true) auto byID(const(string) pkgID)
    {
        return plugins.map!((s) => s.queryID(pkgID))
            .filter!((r) => !r.isNull())
            .map!((r) => RegistryItem(r.get.pkgID, r.get.plugin));
    }

    /**
     * List all items matching the given flags
     */
    pragma(inline, true) auto list(in ItemFlags flags)
    {
        return plugins.map!((s) => s.list(flags)).joiner;
    }

    /**
     * Compute the dependencies for the incoming set of items.
     * This may be used to plan installations *and* removals.
     */
    RegistryItem[] computeItemDependencies(in RegistryItem[] items)
    {
        import moss.deps.digraph : DirectedAcyclicalGraph;
        import std.stdio : writeln;

        /* Build DAG with just our initial input items */
        auto dag = new DirectedAcyclicalGraph!RegistryItem();
        RegistryItem[] workItems = cast(RegistryItem[]) items;
        workItems.each!((i) => dag.addVertex(i));

        /* Keep processing all items until we've built all edges */
        while (workItems.length > 0)
        {
            RegistryItem[] next;

            foreach (item; workItems)
            {
                foreach (dep; item.dependencies)
                {
                    /* TODO: Check if we have this dep already in some fashion */
                    auto providers = byProvider(dep.type, dep.target);
                    if (providers.empty)
                    {
                        writeln("TODO: DISALLOW MISSING DEPENDENCIES: ", dep);
                        continue;
                    }
                    /* TODO: Sort and filter to the correct dependency */
                    auto chosenOne = providers.front;
                    if (!dag.hasVertex(chosenOne))
                    {
                        next ~= chosenOne;
                    }
                    dag.addEdge(item, chosenOne);
                }
            }
            workItems = next;
        }

        RegistryItem[] ret;
        dag.breakCycles();
        dag.topologicalSort((r) { ret ~= r; });
        return ret;
    }

    /**
     * Compute installation of the given items by calculating dependencies
     * and factoring in the existing installation. In future this will also
     * respect conflicts, etc.
     *
     * TODO: This function doesn't actually respect installed items just yet.. :)
     */
    RegistryItem[] computeItemInstallation(in RegistryItem[] items)
    {
        return computeItemDependencies(items);
    }

private:

    RegistryPlugin[] plugins;
}
