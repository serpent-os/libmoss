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

module moss.config.io.snippet;

import std.traits : isArray, OriginalType, FieldNameTuple, getUDAs;
import dyaml;
import std.algorithm : canFind, map;
import std.exception : enforce;
import std.path : baseName;
import std.range : empty;
import std.string : format;
import moss.config.io.schema;

/**
 * A Snippet is a partial or complete file providing some level of merged
 * runtime configuration.
 */
public final class Snippet(C)
{
    @disable this();

    /**
     * Construct a new Snippet for the given path
     */
    this(in string path)
    {
        enforce(!path.empty, "Snippet!" ~ ConfType.stringof ~ ": Path required");
        this._path = path;
        _name = path.baseName;
    }

    /**
     * Returns true if the property was explicitly defined
     */
    pure @property bool explicitlyDefined(in string key, in string id = null) @safe
    {
        auto keyStorageName = id is null ? key : format!"%s/%s"(id, key);
        bool* set = keyStorageName in _explicitlyDefined;
        if (set is null)
        {
            return false;
        }
        return *set;
    }

    /**
     * Begin loading the file
     */
    void load()
    {
        auto loader = Loader.fromFile(path);
        auto rootNode = loader.load();

        /* If we're passed an array configuration, we expect a sequence. */
        static if (arrayConfig)
        {
            enforce(rootNode.type == NodeType.sequence,
                    "Snippet!" ~ C.stringof ~ ": Expected sequence");

            /* Work on each item in the list */
            foreach (ref Node node; rootNode)
            {
                enforce(node.type == NodeType.mapping,
                        "Snippet!" ~ C.stringof
                        ~ ": Each sequence item should be a mapping with an ID");
                Node.Pair[] paired = node.get!(Node.Pair[]);

                /* Capture the ID for this key as we expect ElemType[] */
                immutable string key = paired[0].key.get!string;
                auto value = paired[0].value;

                /* Be unique pls */
                enforce(!_config.canFind!((ref c) => c.id == key),
                        "Snippet!" ~ C.stringof ~ ": Non-unique ID: " ~ key);

                /* Build from value. i.e the struct we can read */
                ElemType builder;
                parseStruct(value, builder, key);
                builder.id = key;

                _config ~= builder;
            }
        }
    }

    /**
     * Expose the configuration as something to be openly abused.
     */
    pragma(inline, true) pure @property ref inout(ConfType) config() @safe @nogc nothrow inout
    {
        return _config;
    }

    /**
     * Return the name of the snippet
     */
    pragma(inline, true) pure @property immutable(string) name() @safe @nogc nothrow const
    {
        return cast(immutable(string)) _name;
    }

    /**
     * Return the path for the file being loaded
     */
    pragma(inline, true) pure @property immutable(string) path() @safe @nogc nothrow const
    {
        return cast(immutable(string)) _path;
    }

    /**
     * Return whether this Snippet is enabled
     */
    pure @property bool enabled() @safe @nogc nothrow const
    {
        return _enabled;
    }

    static if (arrayConfig)
    {

        /**
         * Return the IDs found within this Snippet
         */
        pure auto @property ids() @safe @nogc nothrow const
        {
            return config.map!((ref c) => c.id);
        }
    }

package:

    /**
     * Set enabled property from package classes
     */
    pure @property void enabled(bool b) @safe @nogc nothrow
    {
        _enabled = b;
    }

private:

    alias ConfType = C;

    /* Did we get handed a C[] ? */
    static enum arrayConfig = isArray!ConfType;

    /* Allow struct[] or struct, nothing else */
    static if (arrayConfig)
    {
        alias ElemType = typeof(*ConfType.init.ptr);
        static assert(hasIdentifierField!ElemType,
                "Snippet!" ~ ElemType.stringof ~ ": struct requires an ID field");

    }
    else
    {
        alias ElemType = ConfType;
    }

    /**
     * Return true if the ElemType has an id field, required for any list mapping
     */
    static auto hasIdentifierField(F)()
    {
        F j = F.init;
        static if (is(OriginalType!(typeof(j.id)) == string))
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    static assert(is(ElemType == struct), "Snippet can only be used with structs");

    /**
     * Handle parsing of an individual struct
     */
    void parseStruct(ref Node rootNode, out ElemType elem, string id = null)
    {
        elem = ElemType.init;

        /* Iterate all usable fields */
        static foreach (idx, name; FieldNameTuple!ElemType)
        {
            {
                /* Simplify life, get the local type */
                mixin("alias localType = typeof(__traits(getMember, ElemType, \"" ~ name ~ "\"));");

                static if (!is(localType == string))
                {
                    static assert(!isArray!localType, "parseStruct: Unsupported array: " ~ name);
                }

                /* Grab schema UDA */
                mixin(
                        "enum udas = getUDAs!(__traits(getMember, ElemType, \""
                        ~ name ~ "\"), YamlSchema);");
                YamlSchema schema = YamlSchema.init;
                static if (udas.length > 0)
                {
                    schema = udas[0];
                }

                /* Schema may have a different name */
                auto lookupKey = schema.name.empty ? name : schema.name;

                /* Can we use it? */
                if (rootNode.containsKey(lookupKey))
                {
                    Node val = rootNode[lookupKey];
                    /* TODO: Properly handle types and whatnot. */
                    mixin("elem." ~ name ~ " = val.as!localType;");
                    auto keyStorageName = id is null ? name : format!"%s/%s"(id, name);
                    _explicitlyDefined[keyStorageName] = true;
                }
            }
        }
    }

    ConfType _config;
    string _name = null;
    string _path = null;
    bool _enabled = true;
    bool[string] _explicitlyDefined;
}

import moss.config.io.schema;

/**
 * Get our basic functionality working
 */
private unittest
{
    import std.stdio : writeln;
    import moss.config.repo;

    auto c = new Snippet!(Repository[])("test/repo.yml");
    c.load();
    writeln(c.config);
    writeln(c.ids);
}
