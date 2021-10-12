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

import core.atomic : atomicFetchAdd, atomicStore;
import serpent.ecs;
import moss.deps.query.components;
public import moss.deps.query.source;

import std.algorithm : each, filter, map;

/**
 * The QueryManager is a centralisation point within moss to permit loading
 * "Hot" packages into the runtime system, and query those packages for potential
 * update paths, name resolution, dependencies, etc.
 *
 * At present this is a huge WIP to bolt name resolution into moss, but will ofc
 * be extended in time.
 */
public final class QueryManager
{

    @disable this();

    /**
     * Construct a new QueryManager and initialise the runtime
     * system.
     */
    this(EntityManager entityManager)
    {
        this.entityManager = entityManager;

        /* PackageCandidate */
        entityManager.registerComponent!IDComponent;
        entityManager.registerComponent!NameComponent;
        entityManager.registerComponent!VersionComponent;
        entityManager.registerComponent!ReleaseComponent;
        entityManager.registerComponent!VertexComponent;
        entityManager.registerComponent!DependencyComponent;

        vertexID.atomicStore(0);
    }

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
     * Attempt to load the ID into our runtime
     */
    void loadID(const(string) pkgID)
    {
        loadByProvider(ProviderType.PackageID, pkgID);
    }

    /**
     * Attempt to load all packages with the given name
     */
    void loadName(const(string) pkgID)
    {
        loadByProvider(ProviderType.PackageName, pkgID);
    }

    /**
     * Return all PackageCandidates by Name
     */
    auto byName(const(string) pkgName)
    {
        auto view = View!ReadOnly(entityManager);
        return view.withComponents!(IDComponent, NameComponent,
                VersionComponent, ReleaseComponent, VertexComponent)
            .filter!((tup) => tup[2].name == pkgName)
            .map!((tup) => PackageCandidate(tup[1].id, tup[2].name,
                    tup[3].versionID, tup[4].release, tup[5].vertexID));
    }

    /**
     * Sync all writes for reading
     */
    void update()
    {
        entityManager.step();
    }

private:

    /**
     * Internal helper to load packages by a given provider type
     */
    void loadByProvider(in ProviderType provider, in string matcher)
    {
        auto v = View!ReadWrite(entityManager);

        /**
         * Merge dependency during load
         */
        void mergeDependency(uint32_t dependencyOrigin, in Dependency d)
        {
            auto ent = v.createEntity();
            auto dc = DependencyComponent(dependencyOrigin, d);
            v.addComponent(ent, dc);
        }

        /**
         * Merge packages
         */
        void mergePackages(QuerySource s, in PackageCandidate pkg)
        {
            auto existingPackages = v.withComponents!(IDComponent)
                .filter!((t) => pkg.id == t[1].id);
            if (!existingPackages.empty)
            {
                return;
            }

            auto entity = v.createEntity();
            v.addComponent(entity, IDComponent(pkg.id));
            v.addComponent(entity, NameComponent(pkg.name));
            v.addComponent(entity, VersionComponent(pkg.versionID));
            v.addComponent(entity, ReleaseComponent(pkg.release));
            auto vid = vertexID.atomicFetchAdd(1);
            v.addComponent(entity, VertexComponent(vid));

            s.queryDependencies(pkg.id, (p) => mergeDependency(vid, p));
        }

        sources.each!((s) => {
            s.queryProviders(provider, matcher, (p) => mergePackages(s, p));
        }());
    }

    EntityManager entityManager;
    QuerySource[] sources;
    uint32_t vertexID;
}
