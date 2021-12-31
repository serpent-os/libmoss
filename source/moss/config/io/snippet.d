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

import std.traits : isArray;

/**
 * A Snippet is a partial or complete file providing some level of merged
 * runtime configuration.
 */
public final class Snippet(C)
{
    /**
     * TODO: Load the input path
     */
    void load(in string path)
    {

    }

    /**
     * Expose the configuration as something to be openly abused.
     */
    pure @property ref inout(ConfType) config() @safe @nogc nothrow inout
    {
        return _config;
    }

private:

    alias ConfType = C;

    /* Did we get handled a C[] ? */
    static bool arrayConfig = isArray!ConfType;

    /* Allow struct[] or struct, nothing else */
    static if (isArray!ConfType)
    {
        alias ElemType = typeof(*ConfType.init.ptr);
    }
    else
        static
    {
        alias ElemType = ConfType;
    }

    static assert(is(ElemType == struct), "Snippet can only be used with structs");

    ConfType _config;
}

/**
 * Get our basic functionality working
 */
private unittest
{
    import std.stdio : writeln;

    static struct Repo
    {
        string description;
    }

    auto c = new Snippet!(Repo[])();
    c.load("test/repo.yml");
    writeln(c.config);
}
