/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.schema
 *
 * Defines a custom YAML schema useful for parsing various YAML files
 * used by moss.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.schema;

/**
 * To simplify internal type unmarshalling we have our own basic
 * types of yaml keys
 */
enum YamlType
{
    Single = 0,
    Array = 1,
    Map = 2,
}

/**
 * UDA to help unmarshall the correct values.
 */
struct YamlSchema
{
    /** Name of the YAML key */
    string name;

    /** Is this a mandatory key? */
    bool required = false;

    /** Type of value to expect */
    YamlType type = YamlType.Single;

    /** If set, these are the acceptable string values */
    string[] acceptableValues;
}
