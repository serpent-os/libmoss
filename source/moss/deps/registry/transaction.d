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
import std.algorithm : each, filter, map, canFind;
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
 * Specifies the type of problem encountered processing dependencies
 */
public enum TransactionProblemType
{
    MissingDependency,
}

/**
 * The TransactionProblem is used to describe packaging issues in a way that
 * can trivially be reported to the end user.
 */
public struct TransactionProblem
{
    /**
     * The type of problem we encountered
     */
    TransactionProblemType type;

    /**
     * Item that spawned the issue
     */
    RegistryItem item;

    /**
     * Dependency that was queried
     */
    Dependency dependency;

    /**
     * Return a new TransactionProblem for missing dependencies
     */
    static TransactionProblem missingDependency(in RegistryItem item, in Dependency dependency)
    {
        return TransactionProblem(TransactionProblemType.MissingDependency,
                cast(RegistryItem) item, cast(Dependency) dependency);
    }
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
     * form the new state to apply it.       In essence this is a second fixed DFS
     * of whichever DFS already ran.
     */
    RegistryItem[] apply()
    {
        return computeDependencies(finalState);
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
     * Remove packages from the local state and capture transitive reverse
     * dependencies with multiple transposed subgraphs
     */
    void removePackages(in RegistryItem[] items)
    {
        NullableRegistryItem pickInstalledOnly(in ProviderType type, in string matcher)
        {
            auto installed = this.byProvider(type, matcher);
            if (installed.length < 1)
            {
                return NullableRegistryItem();
            }
            enforce(installed.length == 1,
                    "removePackages(): DAG only supports one unique provider");
            return NullableRegistryItem(installed[0]);
        }

        auto dag = buildGraph(finalState, &pickInstalledOnly);
        dag.breakCycles();

        /* Transpose the graph now */
        auto revgraph = dag.reversed();

        RegistryItem[] removals;

        /* Remove each subgraph resolution */
        foreach (item; items)
        {
            auto subgraph = revgraph.subgraph(item);
            subgraph.topologicalSort((r) { removals ~= r; });
        }

        removed ~= removals;

        finalState = finalState.filter!((i) => !removals.canFind(i)).array();
    }

    /**
     * Return the set items removed by this transaction
     */
    pure @property const(RegistryItem)[] removedItems() @safe @nogc nothrow const
    {
        return cast(const(RegistryItem)[]) removed;
    }

    /**
     * Access all problems with the transaction, if any.
     */
    pure @property const(TransactionProblem)[] problems() @safe @nogc nothrow const
    {
        return cast(const(TransactionProblem)[]) _problems;
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
            /* Disallow duplication on input */
            if (finalState.canFind!((p) => p.pkgID == pkg.pkgID))
            {
                continue;
            }

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
                        "FATAL ERROR: Multiple packages installed with the same name: %s %s".format(provider,
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
        RegistryItem[] ret;

        /* Compute subdomain buckets */
        auto subdomain = new Transaction(registryManager, items);

        NullableRegistryItem pickDependency(in ProviderType type, in string matcher)
        {
            /* Try to find within the newly selected candidates */
            auto newProviders = subdomain.byProvider(type, matcher);
            if (newProviders.length > 0)
            {
                return NullableRegistryItem(newProviders[0]);
            }

            /* Try to find in current selections now */
            auto selectedProviders = byProvider(type, matcher);
            if (selectedProviders.length > 0)
            {
                return NullableRegistryItem(selectedProviders[0]);
            }

            /* Try to find in already installed now */
            auto avail = registryManager.byProvider(type, matcher,
                    ItemFlags.Available).filter!((i) => !i.installed);
            if (avail.empty)
            {
                return NullableRegistryItem(RegistryItem.init);
            }

            /* TODO: Use better logic for selecting "ideal" candidate (sort by repo pinning */
            return NullableRegistryItem(avail.front);
        }

        auto dag = buildGraph(items, &pickDependency);
        dag.breakCycles();
        dag.topologicalSort((r) { ret ~= r; });

        return ret;
    }

    /**
     * Build the graph.
     */
    DirectedAcyclicalGraph!RegistryItem buildGraph(in RegistryItem[] items,
            DependencyLookupFunc depCB)
    {
        auto dag = new DirectedAcyclicalGraph!RegistryItem();

        /* Add the incoming vertices */
        RegistryItem[] workItems = cast(RegistryItem[]) items;
        workItems.each!((i) {
            if (!dag.hasVertex(i))
            {
                dag.addVertex(i);
            }
        });

        /* Keep processing all items until we've built all edges */
        while (workItems.length > 0)
        {
            RegistryItem[] next = null;

            foreach (item; workItems)
            {
                foreach (dep; item.dependencies)
                {
                    if (depCB is null)
                    {
                        continue;
                    }

                    auto chosenOne = depCB(dep.type, dep.target);
                    if (chosenOne.isNull)
                    {
                        _problems ~= TransactionProblem.missingDependency(item, dep);
                        continue;
                    }

                    if (!dag.hasVertex(chosenOne.get))
                    {
                        dag.addVertex(chosenOne.get);
                        next ~= chosenOne.get;
                    }
                    dag.addEdge(item, chosenOne.get);
                }
            }
            workItems = next;
        }

        return dag;
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

    RegistryItem[] added;
    RegistryItem[] removed;
    RegistryItem[] finalState;
    TransactionProblem[] _problems;
    RegistryManager registryManager;
    ProviderBucket[string] providers;

    alias DependencyLookupFunc = NullableRegistryItem delegate(in ProviderType type,
            in string matcher);
}
