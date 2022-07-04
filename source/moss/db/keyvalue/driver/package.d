/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.driver package
 *
 * Driver API for keyvalue databases
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.driver;

import std.experimental.typecons : wrap;

/**
 * All Drivers conform to this interface but are local resource
 * handles.
 */
public interface Driver
{
    void init(const(string) uri) @safe;
    void close() @safe;
}

/**
 * Returns true if the strut matches the Driver API
 */
static bool isDriver(D)()
{
    static if (is(D == struct) && is(typeof({ D val; val.wrap!Driver; return; }()) == void))
    {
        return true;
    }
    else
    {
        return false;
    }
}
