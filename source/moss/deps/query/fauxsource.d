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

/**
 * Helper to populate the faux source
 */
package struct FauxPackage
{
    string name;
    uint64_t release = 0;
    string versionID;

    /* Basic dependencies.. */
    string[] runtimeDepends;
}
/**
 * Our FauxSource is used entirely for unit tests.
 */
package final class FauxSource : QuerySource
{

    /**
     * Add a package to this query source.
     */
    void addPackage(const(string) pkgID, ref FauxPackage p)
    {
        packages[pkgID] = p;
    }

    /**
     * Return a queryable package
     */
    override QueryResult queryID(const(string) pkgID)
    {
        auto p = pkgID in packages;
        if (p !is null)
        {
            return QueryResult(PackageCandidate(pkgID, p.name, p.versionID, p.release), true);
        }
        return QueryResult(PackageCandidate.init, false);
    }

private:

    FauxPackage[string] packages;
}

/**
 * Ensure basic query is working as expected.
 */
unittest
{
    import moss.deps.query : QueryManager;
    import serpent.ecs : EntityManager;
    import std.exception : enforce;
    import std.array : array;

    auto em = new EntityManager();
    auto qm = new QueryManager(em);
    auto fs = new FauxSource();
    qm.addSource(fs);
    em.build();
    em.step();

    auto nanoPkg = FauxPackage("nano", 12, "2.4");
    auto nanoPkg2 = FauxPackage("nano", 13, "2.5");
    fs.addPackage("nano-pkg1", nanoPkg);
    fs.addPackage("nano-pkg2", nanoPkg2);

    qm.update();
    qm.loadID("nano-pkg1");
    qm.loadID("nano-pkg2");

    auto result = qm.byName("nano").array;
    enforce(result.length == 2);
    enforce(result[0].versionID == "2.4");
    enforce(result[1].versionID == "2.5");

    scope (exit)
    {
        qm.update();
        em.destroy();
    }
}
