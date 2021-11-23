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

module moss.deps.registry.transaction;

import moss.deps.dependency;
public import moss.deps.registry.item;
public import moss.deps.registry.manager;
import std.exception : enforce;

import std.string : format;
import std.conv : to;
import std.array : array;
import std.algorithm : each, filter, map;
import moss.deps.digraph;

/**
 * Light version of Registryitem without the mutability issues
 */
private struct ProviderItem
{
    string pkgID;
    RegistryPlugin plugin;
    ItemFlags flags;
}
/**
 * Maps providers locally so we can make more informed "satisfied" decisions
 * without skipping the installed/selected candidates.
 */
private struct ProviderBucket
{
    ProviderItem[string] mappings;
}

/**
 * A Transaction is created by the RegistryManager to track the changes needed
 * to go from one state to another. Stricly speaking moss only requires the
 * knowledge of *fully applied state*, however users are interested in mutations
 * and it helps us to ensure no name duplication across IDs.
 */
public final class Transaction
{

    @disable this();

    /**
     * Compute the final state. This is needed by moss to know what selections
     * form the new state to apply it.
     */
    RegistryItem[] apply() @safe
    {

        return finalState;
    }

    /**
     * TODO: Make this install packages!
     */
    void installPackages(in RegistryItem[] items)
    {
        auto deps = computeDependencies(items);

        /* TODO: Work out replacements by Name etc */
        finalState ~= deps;
    }

    /**
     * TODO: Make this remove packages!
     */
    void removePackages(in RegistryItem[] items)
    {

    }

package:

    /**
     * Construct a new Transaction object with the input base state
     */
    this(RegistryManager registryManager)
    {
        this(registryManager, registryManager.listInstalled().array());
    }

private:

    /**
     * Create new Transaction for the given items
     */
    this(RegistryManager registryManager, in RegistryItem[] items)
    {
        this.registryManager = registryManager;

        foreach (pkg; items)
        {
            foreach (provider; pkg.providers)
            {
                /* Make sure we don't duplicate a package name */
                addProvider(pkg, provider);
                if (provider.type != ProviderType.PackageName)
                {
                    continue;
                }
                auto nameProvider = byProvider(provider.type, provider.target);
                enforce(nameProvider.length == 1,
                        "FATAL ERROR: Multiple packages installed with the same name: %s".format(
                            nameProvider));
            }
            finalState ~= cast(RegistryItem) pkg;
        }
    }

    /**
     * Return all dependencies for the incoming set.
     *
     * This function may pick from the given selection, the locally installed
     * selection and finally the repo itself.
     */
    auto computeDependencies(in RegistryItem[] items)
    {
        import std.stdio : writeln;

        RegistryItem[] ret;
        auto dag = new DirectedAcyclicalGraph!RegistryItem();

        /* Compute subdomain buckets */
        auto subdomain = new Transaction(registryManager, items);

        /* Add the incoming vertices */
        RegistryItem[] workItems = cast(RegistryItem[]) items;
        workItems.each!((i) => dag.addVertex(i));

        /* Keep processing all items until we've built all edges */
        while (workItems.length > 0)
        {
            RegistryItem[] next = null;

            foreach (item; workItems)
            {
                foreach (dep; item.dependencies)
                {
                    Nullable!RegistryItem chosenOne = Nullable!RegistryItem(RegistryItem.init);

                    /* Already selected */
                    auto selectedProviders = byProvider(dep.type, dep.target);

                    /* Scoped to the new selection */
                    auto newProviders = subdomain.byProvider(dep.type, dep.target);

                    /* Potential "new" providers */
                    auto remoteProviders = registryManager.byProvider(dep.type,
                            dep.target, ItemFlags.Available).filter!((i) => !i.installed);

                    if (newProviders.length > 0)
                    {
                        /* Grab from new providers first */
                        chosenOne = newProviders[0];
                    }
                    else if (selectedProviders.length > 0)
                    {
                        /* Grab from existing providers */
                        chosenOne = selectedProviders[0];
                    }
                    else
                    {
                        if (remoteProviders.empty)
                        {
                            writeln("TODO: Make missing dependency fatal: ", dep);
                            continue;
                        }
                        chosenOne = remoteProviders.front;
                    }

                    if (chosenOne.isNull)
                    {
                        continue;
                    }

                    if (!dag.hasVertex(chosenOne.get))
                    {
                        next ~= chosenOne.get;
                    }
                    dag.addEdge(item, chosenOne.get);
                }
            }
            workItems = next;
        }

        dag.breakCycles();
        dag.topologicalSort((r) { ret ~= r; });

        return ret;
    }

    /**
     * Cache known providers to allow transaction specific memory of
     * our own selections.
     */
    void addProvider(in RegistryItem item, in Provider p)
    {

        auto bucketName = "%s.%s".format(p.type, p.target);
        auto lookupNode = bucketName in providers;
        if (lookupNode is null)
        {
            providers[bucketName] = ProviderBucket();
            lookupNode = &providers[bucketName];
        }
        lookupNode.mappings[item.pkgID] = ProviderItem(item.pkgID,
                cast(RegistryPlugin) item.plugin, item.flags);
    }

    auto byProvider(in ProviderType p, in string matcher)
    {
        auto bucketName = "%s.%s".format(p, matcher);
        auto lookupNode = bucketName in providers;

        if (lookupNode is null)
        {
            return null;
        }

        return lookupNode.mappings.values.map!((m) => RegistryItem(m.pkgID,
                m.plugin, m.flags)).array;
    }

    string[] added;
    string[] removed;
    RegistryItem[] finalState;
    RegistryManager registryManager;
    ProviderBucket[string] providers;
}
