/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.registry.fauxsource
 *
 * Defines unit test specific functionality.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.registry.fauxsource;

public import moss.deps.registry.plugin;

import std.algorithm : each, filter, map;
import std.array : array;
import moss.deps.registry.candidate;

@trusted:

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
        case ProviderType.CmakeName:
        case ProviderType.PkgconfigName:
        case ProviderType.PythonName:
        case ProviderType.Interpreter:
        case ProviderType.BinaryName:
        case ProviderType.SystemBinaryName:
        case ProviderType.Pkgconfig32Name:
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
    override Job fetchItem(in string pkgID)
    {
        return null;
    }

    override void close()
    {
    }

    override pure @property uint64_t priority() @safe @nogc nothrow const
    {
        return 0;
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
    import moss.deps : Dag;

    auto qm = new RegistryManager();
    auto fs = new FauxSource();
    qm.addPlugin(fs);

    worldPackages.each!((p) { fs.addPackage(p); });

    auto result = qm.byName("nano").array;
    enforce(result.length == 1);
    auto nano = result[0];
    enforce(nano.dependencies.length == 2);

    auto dg = Dag!string();
    void addRecurse(in string pkgID)
    {
        dg.addNode(pkgID);
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

    const auto computedOrder = dg.topologicalSort().array;
    assert(computedOrder == ["baselayout", "glibc", "ncurses", "nano"]);

    dg.emitGraph();

    auto unknownName = qm.byName("not known");
    assert(unknownName.empty);

    auto unknownSymbol = qm.byProvider(ProviderType.SharedLibraryName, "libz.so.1(x86_64)");
    assert(unknownSymbol.empty);

    auto revdepsGraph = dg.reversed().subGraph("ncurses");
    auto revdepsOrder = revdepsGraph.topologicalSort().array;
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
    assert(names == ["baselayout", "glibc", "ncurses", "nano", "bash"]);
}
