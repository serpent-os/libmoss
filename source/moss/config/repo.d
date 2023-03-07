/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.config.repo
 *
 * Repository configuration functionality for moss.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.config.repo;

import std.string : format;
import moss.config.io.schema;
import moss.config.io.configuration;

public import std.stdint : uint64_t;

/**
 * Provide a sane alias for typing
 */
public alias RepositoryConfiguration = Configuration!(Repository[]);

/**
 * Holds all the relevant details for Repository deserialisation from
 * a set of YML files
 */
@ConfigurationDomain("moss", "repos") public struct Repository
{
    /**
     * Unique identifier for the repository
     */
    string id = null;

    /**
     * A human description for this repository
     */
    string description = null;

    /**
     * Where does one find said repository
     */
    @YamlSchema("uri", true) string uri = null;

    /**
     * Higher priority = pin behaviour
     */
    uint64_t priority = 0;

    /**
     * Return a human readable description of the repo
     */
    pure @property auto toString()
    {
        if (description !is null)
        {
            return format!"%s - \"%s\" (%s @%s)"(id, uri, description, priority);
        }
        return format!"%s - \"%s\" @ %s"(id, uri, priority);
    }
}
