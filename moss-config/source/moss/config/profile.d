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
module moss.config.profile;

import std.string : format;
import moss.config.io.schema;
import moss.config.io.configuration;

public import std.stdint : uint64_t;
public import moss.config.repo;

/**
 * Provide a sane alias for typing
 */
public alias ProfileConfiguration = Configuration!(Profile[]);

/**
 * Holds all the relevant details for Repository deserialisation from
 * a set of YML files
 */
@ConfigurationDomain("boulder", "profiles") public struct Profile
{
    /**
     * Unique identifier
     */
    string id;

    /**
     * Collections in this profile
     */
    Repository[] collections;
}
