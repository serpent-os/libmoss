/*
 * This file is part of moss-config.
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

module moss.config.repo;

import std.string : format;
import moss.config.io.schema;
import moss.config.io.configuration;

/**
 * Provide a sane alias for typing
 */
public alias RepositoryConfiguration = Configuration!(Repository[]);

/**
 * Holds all the relevant details for Repository deserialisation from
 * a set of YML files
 */
@DomainKey("repos") public struct Repository
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
     * Return a human readable description of the repo
     */
    pure @property auto toString()
    {
        if (description !is null)
        {
            return format!"%s - \"%s\" (%s)"(id, uri, description);
        }
        return format!"%s - \"%s\""(id, uri);
    }
}
