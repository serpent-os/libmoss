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

import moss.db.keyvalue.errors;
import moss.db.keyvalue.interfaces;

/**
 * All Drivers conform to this interface but are local resource
 * handles.
 */
public interface Driver
{
    DatabaseResult connect(const(string) uri, DatabaseFlags flags) @safe;
    void close() @safe;
}
