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

module moss.deps.query.manager;

public import moss.deps.query.source;

import std.algorithm : each, filter, map;

/**
 * Encapsulation of multiple underlying "query sources"
 */
public final class QueryManager
{
    /**
     * Add a source to the QueryManager
     */
    void addSource(QuerySource source)
    {
        sources ~= source;
    }

    /**
     * Remove an existing source from this manager
     */
    void removeSource(QuerySource source)
    {
        import std.algorithm : remove;

        sources = sources.remove!((s) => s == source);
    }

    /**
     * Return all PackageCandidates by provider
     */
    auto byProvider(in MatchType MatchType, const(string) provider)
    {
        import std.algorithm : joiner;

        return sources.map!((s) => s.queryProviders(MatchType, provider)).joiner();
    }

    /**
     * Return all PackageCandidates by Name
     */
    pragma(inline, true) auto byName(const(string) pkgName)
    {
        return byProvider(MatchType.PackageName, pkgName);
    }

    /**
     * Return all PackageCandidates by ID
     */
    pragma(inline, true) auto byID(const(string) pkgID)
    {
        return byProvider(MatchType.PackageID, pkgID);
    }

private:

    QuerySource[] sources;
}
