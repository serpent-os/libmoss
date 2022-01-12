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

module moss.deps.registry.fauxsource;

public import moss.deps.registry.plugin;

import std.algorithm : each, filter, map;
import std.array : array;
import moss.deps.registry.candidate;

/**
 * Our FauxSource is used entirely for unit tests.
 */
package final class FauxSource : RegistryPlugin
{

    /**
     * Add a package to this query source.
     */
    void addPackage(ref PackageCandidate p)
    {
        packages[p.id] = p;
    }

    /**
     * Return the registry item corresponding to pkgID
     */
    override NullableRegistryItem queryID(in string pkgID)
    {
        auto result = pkgID in packages;
        if (result !is null)
        {
            return NullableRegistryItem(RegistryItem(result.id, this));
        }

        return NullableRegistryItem();
    }

    override RegistryItem[] queryProviders(in ProviderType type, in string matcher,
            ItemFlags flags = ItemFlags.None)
    {
        final switch (type)
        {
        case ProviderType.PkgconfigName:
        case ProviderType.Interpreter:
            return [];
        case ProviderType.PackageName:
            return packages.values
                .filter!((ref p) => p.name == matcher)
                .map!((ref p) => RegistryItem(p.id, this))
                .array();
        case ProviderType.SharedLibraryName:
            if (matcher == "libc.so.6(x86_64)")
            {
                return [RegistryItem(packages["glibc"].id, this)];
            }
            return null;
        }
    }

    /**
     * We're simple, we don't provide any information support in this plugin
     */
    override ItemInfo info(in string pkgID) const
    {
        return ItemInfo();
    }

    /**
     * Currently not supporting this.
     */
    override const(RegistryItem)[] list(in ItemFlags flags) const
    {
        return null;
    }

    /**
     * Grab dependencies for the given package
     */
    override const(Dependency)[] dependencies(in string pkgID) const
    {
        if (!(pkgID in packages))
        {
            return null;
        }
        return packages[pkgID].dependencies;
    }

    /**
     * Grab providers for the given package
     */
    override const(Provider)[] providers(in string pkgID) const
    {
        return [];
    }

    /* no op */
    override void fetchItem(FetchContext context, in string pkgID)
    {

    }

    override void close()
    {
    }

    PackageCandidate[string] packages;
}

/**
 * Helpers for defining packages
 */
import moss.deps.dependency : DependencyType, Dependency;

static PackageCandidate P(const(string) name)
{
    return PackageCandidate(name, name, "no.version", 1, []);
}

static PackageCandidate P(const(string) name, Dependency[] deps)
{
    return PackageCandidate(name, name, "no.version", 1, deps);
}

static Dependency D(const(string) name)
{
    return Dependency(name, DependencyType.PackageName);
}

static Dependency LD(const(string) name)
{
    return Dependency(name, DependencyType.SharedLibraryName);
}

static PackageCandidate[] worldPackages = [
    P("bash", [LD("libc.so.6(x86_64)"), D("ncurses"),]),
    P("nano", [LD("libc.so.6(x86_64)"), D("ncurses"),]),
    P("ncurses", [LD("libc.so.6(x86_64)"),]), P("baselayout", []),
    P("glibc", [D("baselayout")]),
];

/**
 * Ensure basic query is working as expected.
 */
unittest
{
    import moss.deps.registry : RegistryManager, RegistryItem;
    import std.exception : enforce;
    import moss.deps : DirectedAcyclicalGraph;

    auto qm = new RegistryManager();
    auto fs = new FauxSource();
    qm.addPlugin(fs);

    worldPackages.each!((p) { fs.addPackage(p); });

    auto result = qm.byName("nano").array;
    enforce(result.length == 1);
    auto nano = result[0];
    enforce(nano.dependencies.length == 2);

    auto dg = new DirectedAcyclicalGraph!string();
    void addRecurse(in string pkgID)
    {
        if (!dg.hasVertex(pkgID))
        {
            dg.addVertex(pkgID);
        }
        auto results = qm.byID(pkgID);
        assert(!results.empty);
        foreach (dep; results.front.dependencies)
        {
            auto r = qm.byProvider(dep.type, dep.target);
            enforce(!r.empty);
            addRecurse(r.front.pkgID);
            dg.addEdge(pkgID, r.front.pkgID);
        }
    }

    addRecurse(nano.pkgID);

    string[] computedOrder;
    dg.topologicalSort((n) { computedOrder ~= n; });
    assert(computedOrder == ["baselayout", "glibc", "ncurses", "nano"]);

    dg.emitGraph();

    auto unknownName = qm.byName("not known");
    assert(unknownName.empty);

    auto unknownSymbol = qm.byProvider(ProviderType.SharedLibraryName, "libz.so.1(x86_64)");
    assert(unknownSymbol.empty);

    auto revdepsGraph = dg.reversed().subgraph("ncurses");
    string[] revdepsOrder;
    revdepsGraph.topologicalSort((n) { revdepsOrder ~= n; });
    assert(revdepsOrder == ["nano", "ncurses"]);
}

/**
 * Ensure manager integration works and we can preselect in batch
 */
unittest
{
    import moss.deps.registry : RegistryManager, RegistryItem;

    auto fp = new FauxSource();
    auto reg = new RegistryManager();
    reg.addPlugin(fp);
    worldPackages.each!((p) => fp.addPackage(p));

    auto tr = reg.transaction();
    auto nanoPkg = reg.byName("nano").front;
    auto bashPkg = reg.byName("bash").front;
    tr.installPackages([nanoPkg, bashPkg, bashPkg]);
    auto res = tr.apply();
    assert(tr.problems.length == 0);
    auto names = res.map!((p) => p.pkgID).array();
    assert(names == ["baselayout", "glibc", "ncurses", "bash", "nano"]);
}
