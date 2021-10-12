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

module moss.deps.query.fauxsource;

public import moss.deps.query.source;

import std.algorithm : each, filter, map;
import std.array : array;

/**
 * Our FauxSource is used entirely for unit tests.
 */
package final class FauxSource : QuerySource
{

    /**
     * Add a package to this query source.
     */
    void addPackage(ref PackageCandidate p)
    {
        packages[p.id] = p;
    }

    override const(PackageCandidate)[] queryProviders(in ProviderType type, in string matcher)
    {
        final switch (type)
        {
        case ProviderType.PackageID:
            auto p = matcher in packages;
            if (p is null)
            {
                return null;
            }
            return [PackageCandidate(p.id, p.name, p.versionID, p.release)];

        case ProviderType.PackageName:
            return packages.values.filter!((ref p) => p.name == matcher).array();
        }
    }

    PackageCandidate[string] packages;
}

import moss.deps.query.dependency : DependencyType, Dependency;

static PackageCandidate[] worldPackages = [
    PackageCandidate("nano", "nano", "2.4", 12, 0, [
            Dependency("ncurses", DependencyType.PackageName),
            Dependency("glibc", DependencyType.PackageName),
            ]),
    PackageCandidate("glibc", "glibc", "2.17", 1, 0, [
            Dependency("baselayout", DependencyType.PackageName),
            ]),
    PackageCandidate("ncurses", "ncurses", "6.2", 2, 0, [
            Dependency("glibc", DependencyType.PackageName),
            ]), PackageCandidate("baselayout", "baselayout", "1.0", 50, 0),
];

/**
 * Ensure basic query is working as expected.
 */
unittest
{
    import moss.deps.query : QueryManager;
    import std.exception : enforce;

    auto qm = new QueryManager();
    auto fs = new FauxSource();
    qm.addSource(fs);

    worldPackages.each!((p) => fs.addPackage(p));

    auto result = qm.byName("nano").array;
    enforce(result.length == 1);
    enforce(result[0].versionID == "2.4");
}
