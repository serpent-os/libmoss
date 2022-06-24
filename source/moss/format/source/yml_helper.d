/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.yml_helper
 *
 * Helper functions for applying and enforcing schemas when parsing
 * YAML format files.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.yml_helper;

import dyaml;
import moss.format.source.schema;
import std.stdint;

/**
 * Set value appropriately.
 */
void setValue(T)(ref Node node, ref T value, YamlSchema schema)
{
    import std.exception : enforce;
    import std.algorithm : canFind;
    import std.string : format;

    enforce(node.nodeID == NodeID.scalar, "Expected " ~ T.stringof ~ " for " ~ node.tag);

    static if (is(T == int64_t))
    {
        value = node.as!int64_t;
    }
    else static if (is(T == uint64_t))
    {
        value = node.as!uint64_t;
    }
    else static if (is(T == bool))
    {
        value = node.as!bool;
    }
    else
    {
        value = node.as!string;
        if (schema.acceptableValues.length < 1)
        {
            return;
        }

        /* Make sure the string is an acceptable value */
        enforce(schema.acceptableValues.canFind(value),
                "setValue(): %s not a valid value for %s. Acceptable values: %s".format(value,
                    schema.name, schema.acceptableValues));
    }
}

/**
 * Set value according to maps.
 */
void setValueArray(T)(ref Node node, ref T value)
{
    import std.exception : enforce;

    /* We can support a single value *or* a list. */
    enforce(node.nodeID != NodeID.mapping, "Expected " ~ T.stringof ~ " for " ~ node.tag);

    switch (node.nodeID)
    {
        static if (is(T == string) || is(T == string[]))
        {
    case NodeID.scalar:
            value ~= node.as!string;
            break;
    case NodeID.sequence:
            foreach (ref Node v; node)
            {
                value ~= v.as!string;
            }
            break;
        }
        else
        {
    case NodeID.scalar:
            value ~= node.as!(typeof(value[0]));
            break;
    case NodeID.sequence:
            foreach (ref Node v; node)
            {
                value ~= v.as(typeof(value[0]));
            }
            break;
        }
    default:
        break;
    }
}

/**
 * Parse a section in the YAML by the given input node + section, setting as
 * many automatic values as possible using our UDA helper system
 */
void parseSection(T)(ref Node node, ref T section) @system
{
    import std.traits : getUDAs, moduleName;
    import std.exception : enforce;

    /* Walk members */
    static foreach (member; __traits(allMembers, T))
    {
        {
            mixin("import " ~ moduleName!T ~ ";");

            mixin("enum udaID = getUDAs!(" ~ T.stringof ~ "." ~ member ~ ", YamlSchema);");
            static if (udaID.length == 1)
            {
                static assert(udaID.length == 1, "Missing YamlSchema for " ~ T.stringof
                        ~ "." ~ member);
                enum yamlName = udaID[0].name;
                enum mandatory = udaID[0].required;
                enum type = udaID[0].type;

                static if (mandatory)
                {
                    enforce(node.containsKey(yamlName), "Missing mandatory key: " ~ yamlName);
                }

                static if (type == YamlType.Single)
                {
                    if (node.containsKey(yamlName))
                    {
                        mixin("setValue(node[yamlName], section." ~ member ~ ", udaID);");
                    }
                }
                else static if (type == YamlType.Array)
                {
                    if (node.containsKey(yamlName))
                    {
                        mixin("setValueArray(node[yamlName], section." ~ member ~ ");");
                    }
                }
            }
        }
    }
}
