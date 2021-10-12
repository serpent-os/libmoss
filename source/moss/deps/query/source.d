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

module moss.deps.query.source;

public import moss.deps.query.candidate;
public import moss.deps.query.dependency;

/**
 * When querying we can lookup by name, ID, etc.
 */
enum ProviderType
{
    PackageName,
    PackageID,
}

/**
 * QueryResult can be successful (found) and set, or empty and false
 */
public struct QueryResult
{
    /**
     * Candidate to return if the query was successfully found
     */
    PackageCandidate candidate;

    /**
     * Set to true if we find the candidate
     */
    bool found = false;
}

/**
 * A QueryCallback is provided to QuerySource implementations so that the owning
 * QueryManager can build a list of potential candidates from incoming sources
 */
alias QueryCallback = void delegate(in PackageCandidate candidate);

alias DependencyCallback = void delegate(in Dependency dependency);

/**
 * A QuerySource is added to the QueryManager allowing it to load data from pkgIDs
 * if present.
 */
public interface QuerySource
{
    /**
     * The QuerySource will be given a callback to execute if it finds any
     * matching providers for the input string and type
     */
    void queryProviders(in ProviderType type, in string matcher, QueryCallback merger);

    /**
     * The queryDependencies call will usually happen within the context of the
     * QueryCallback call of queryProviders, to allow merging the dependencies
     * of a given package without relying on extra allocations.
     */
    void queryDependencies(in string pkgID, DependencyCallback merger);
}
