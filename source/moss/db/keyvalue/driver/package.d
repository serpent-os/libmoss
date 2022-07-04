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

/**
 * All Drivers conform to this interface but are local resource
 * handles.
 */
public interface Driver
{
    void connect(const(string) uri) @safe;
    void close() @safe;
}
