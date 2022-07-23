/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.orm.types
 *
 * Base types/decorators for the ORM system
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.orm.types;

/**
 * UDA: Decorate a field as the primary key in a model
 */
struct PrimaryKey
{
    /**
     * Automatically increment for each key insertion.
     * Requires an integer type
     */
    bool autoIncrement;
}

/**
 * UDA: Construct a two-way mapping for quick indexing
 */
struct Indexed
{
}

/**
 * UDA: Marks a model as consumable.
 */
struct Model
{
    /**
     * Override the table name
     */
    string name;
}
