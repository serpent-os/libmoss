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

    override const(PackageCandidate)[] queryProviders(in MatchType type, in string matcher)
    {
        final switch (type)
        {
        case MatchType.PackageID:
            auto p = matcher in packages;
            if (p is null)
            {
                return null;
            }
            return [
                PackageCandidate(p.id, p.name, p.versionID, p.release, p.dependencies)
            ];

        case MatchType.PackageName:
            return packages.values.filter!((ref p) => p.name == matcher).array();
        case MatchType.LibraryName:
            if (matcher == "libc.so.6")
            {
                return [packages["glibc"]];
            }
            return [];
        }
    }

    PackageCandidate[string] packages;
}

/**
 * Helpers for defining packages
 */
import moss.deps.registry.dependency : DependencyType, Dependency;

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
    P("nano", [LD("libc.so.6"), D("ncurses"),]), P("ncurses", [
            LD("libc.so.6"),
            ]), P("baselayout", []), P("glibc", [D("baselayout")]),
];

/**
 * Ensure basic query is working as expected.
 */
unittest
{
    import moss.deps.registry : RegistryManager;
    import std.exception : enforce;
    import moss.deps.graph : DependencyGraph;

    auto qm = new RegistryManager();
    auto fs = new FauxSource();
    qm.addPlugin(fs);

    worldPackages.each!((p) => fs.addPackage(p));

    auto result = qm.byName("nano").array;
    enforce(result.length == 1);
    auto nano = result[0];
    enforce(nano.dependencies.length == 2);

    auto g = new DependencyGraph!string;

    /**
     * TODO: Change to a nice loop.
     */
    void addRecursive(in PackageCandidate p)
    {
        if (!g.hasNode(p.id))
        {
            g.addNode(p.id);
        }
        foreach (dep; p.dependencies)
        {
            PackageCandidate candidate;

            switch (dep.type)
            {
            case DependencyType.PackageName:
                auto c = qm.byName(dep.target);
                enforce(!c.empty);
                candidate = cast(PackageCandidate) c.front;
                break;
            case DependencyType.SharedLibraryName:
                auto c = qm.byProvider(MatchType.LibraryName, dep.target);
                enforce(!c.empty);
                candidate = cast(PackageCandidate) c.front;
                break;
            default:
                assert(0 == 1, "UNHANDLED DEPENDENCY");
            }
            g.addEdge(p.id, candidate.id);
            addRecursive(candidate);
        }
    }

    auto nanoCandidates = qm.byID("nano").array;
    enforce(nanoCandidates.length == 1);
    auto nanoC = nanoCandidates[0];
    addRecursive(nanoC);
    string[] computedOrder;
    g.topologicalSort((n) => { computedOrder ~= n; }());

    import std.stdio : writeln;

    enforce(computedOrder == ["baselayout", "glibc", "ncurses", "nano"]);
    g.emitGraph();

}
