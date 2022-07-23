/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.keyvalue.orm
 *
 * Compile time ORM support for moss-db
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.db.keyvalue.orm;

public import moss.db.keyvalue.orm.types;

@("Basic ORM testing") @safe unittest
{
    @Model static struct User
    {
        @PrimaryKey int id;
    }

    static assert(isValidModel!User, "User should be a valid model");
}
