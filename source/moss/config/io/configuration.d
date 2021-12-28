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

module moss.config.io.configuration;
import std.path : buildPath;
import std.exception : enforce;

/**
 * configSuffix is set per file (snippet)
 */
public static immutable(string) configSuffix = ".conf";

/**
 * configDir is added to domain to compute configuration directories
 */
public static immutable(string) configDir = ".d";

/**
 * Required directories that form the basis of a Configuration
 */
package enum Directories : string
{
    Vendor = buildPath("usr", "share", "moss"),
    Admin = buildPath("etc", "moss")
}

/**
 * The Configuration is merged from multiple snippet sources which can be
 * individually enabled/masked/etc
 */
public final class Configuration
{
    @disable this();

    /**
     * Construct a new Configuration with the given domain
     */
    this(in string domain)
    {
        this.domain = domain;
    }

    /**
     * Return the domain for this configuration (i.e. "repos")
     */
    pragma(inline, true) pure @property const(string) domain() @safe @nogc nothrow
    {
        return _domain;
    }

private:

    /**
     * Set the domain
     */
    @property void domain(in string d) @safe
    {
        enforce(d !is null);
        _domain = d;
    }

    string _domain = null;
}
