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

import std.range : ElementType;
import std.traits;
import moss.core.encoding;

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

/**
 * Determine model decorator presence
 *
 * Params:
 *      M = Model to validate
 * Returns: true if the model is decorated correctly
 */
static bool hasModelDecorator(M)()
{
    static if (hasUDA!(M, Model))
    {
        return true;
    }
    else
    {
        return false;
    }
}
/**
 * Return true if a primary key was found.
 *
 * Params:
 *      M = Model to validate
 * Returns: true if model valid
 */
static bool hasPrimaryKey(M)()
{
    static if (getSymbolsByUDA!(M, PrimaryKey).length != 1)
    {
        return false;
    }
    else
    {
        return true;
    }
}

/**
 * Allow runtime/compile time checking
 *
 * Params:
 *      M = Model to validate
 * Returns: true if model valid
 */
static bool isValidModel(M)()
        if (hasModelDecorator!M && hasPrimaryKey!M && isEncodable!M
            && __traits(isPOD, M) && is(OriginalType!M == struct))
{
    return true;
}

/**
 * Determine if the slice element is encodable
 *
 * Params:
 *      F = field type
 * Returns: true if encoding is supported
 */
static bool isEncodableSlice(F)()
{
    bool ret;
    static if ((!isSomeString!F && isArray!F) && isMossEncodable!(ElementType!F))
    {
        ret = true;
    }
    return ret;
}

/**
 * Determine if the field in M is @Indexed
 *
 * Params:
 *      M = Model
 *      F = Field
 * Returns: true if @Indexed
 */
static bool isFieldIndexed(M, alias F)()
{
    bool ret;
    static if (getUDAs!(mixin("M." ~ F), Indexed).length > 0)
    {
        ret = true;
    }
    return ret;
}

/**
 * Helper to deterine the field type
 *
 * Params:
 *      M = Model type
 *      F = field name
 */
static template getFieldType(M, alias F)
{
    alias getFieldType = OriginalType!(Unconst!(typeof(__traits(getMember, M, F))));
}

/**
 * Return true if we can encode this type
 *
 * Params:
 *      M = Model to validate
 * Returns: true if model valid
 */
static bool isEncodable(M)()
{
    bool ret = true;
    static foreach (field; __traits(allMembers, M))
    {
        {
            alias fieldType = OriginalType!(typeof(__traits(getMember, M, field)));
            static if (!isMossEncodable!fieldType && !isEncodableSlice!fieldType)
            {
                /* Let the dev know why this doesn't work */
                pragma(msg,
                        Unconst!M.stringof ~ "." ~ field ~ ": Type ("
                        ~ fieldType.stringof ~ ") is not mossEncodable");
                ret = false;
            }
        }
    }
    return ret;
}

/**
 * Return the Model() for the Model type.
 */
private auto getModel(M)()
{
    static if (is(typeof(getUDAs!(M, Model)[0]) == Model))
    {
        return getUDAs!(M, Model)[0];
    }
    else
    {
        return Model();
    }
}

/**
 * Retrieve the model name (bucket name) for the model.
 *
 * Params:
 *      M = Model
 * Returns: Name to use for the model
 */
public static auto modelName(M)() @safe if (isValidModel!M)
{
    import std.string : toLower, endsWith;
    import std.range : empty;

    enum model = getModel!M;

    static if (!model.name.empty)
    {
        enum name = model.name;
    }
    else
    {
        enum name = (Unconst!M).stringof.toLower();
    }
    return name.endsWith("s") ? name : name ~ "s";
}

/**
 * Compute index bucket name for specific index
 *
 * Params:
 *      M = Model
 *      field = Field that is indexed
 * Returns:  a string like "users#index.name"
 */
public static auto indexName(M, alias field)() @safe if (isValidModel!M)
{
    return (modelName!M ~ "#index." ~ field).mossEncode;
}

/**
 * Compute basename for each row
 *
 * If the model name is "user" (struct User, table users) then
 * this will result in ".user." for the row base name, making
 * room for the suffix.
 *
 * Params:
 *      M = Model
 * Returns: Moss encoded row base name
 */
public static auto rowBaseName(M)() @safe if (isValidModel!(M))
{
    import std.string : toLower, endsWith;
    import std.range : empty;

    enum model = getModel!M;

    static if (!model.name.empty)
    {
        enum name = model.name;
    }
    else
    {
        enum name = (Unconst!M).stringof.toLower();
    }

    return ("." ~ name ~ ".").mossEncode();
}

/**
 * Retrieve the row "name" for a model entry, i.e.
 * .user.1
 * This is already encoded as a bucket name correctly
 *
 * Params:
 *      M = Model
 *      obj = Model object to generate an ID for
 * Returns: moss encoded row name
 */
public ImmutableDatum rowName(M)(in M obj) @safe if (isValidModel!M)
{
    mixin("auto pkey = obj." ~ getSymbolsByUDA!(M, PrimaryKey)[0].stringof ~ ";");
    return rowBaseName!M ~ (pkey.mossEncode);
}
