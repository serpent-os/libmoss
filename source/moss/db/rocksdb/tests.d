/*
 * This file is part of moss.
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

/**
 * This module simply contains a batch of unit tests 
 */
module moss.db.rocksdb.tests;

import moss.db.rocksdb;
import std.file : exists;

static private const auto dbLocation = "testDB";

/**
 * Helper to nuke the old DB from the disk
 */
static private void cleanupDB(scope Database db)
{
    db.close();
    import std.file : rmdirRecurse;

    dbLocation.rmdirRecurse();
}

/**
 * Simple open/close operation, ensure DB actually exists
 */
private unittest
{
    auto db = new RDBDatabase(dbLocation, DatabaseMutability.ReadWrite);

    assert(dbLocation.exists, "Database not created");
    scope (exit)
    {
        cleanupDB(db);
    }
}
