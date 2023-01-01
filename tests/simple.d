/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Basic moss-config tests
 *
 * Simple use-case moss-config testing
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module simple;

import moss.config.io;
import moss.config.repo;
import moss.config.profile;
import std.stdio : writeln;

@("Primitive testing")
unittest
{
    auto n = new Configuration!(Repository[])();
    n.load("../tests/");

    assert(n.sections.length == 1);
}

import moss.config.io.schema;

@("Ensure direct YML loading works")
private unittest
{
    auto c = new Snippet!(Repository[])("../tests/repo.yml");
    c.load();
    assert(c.config.length == 1);
    auto testItem = Repository("bootstrap", "Serpent OS (Protosnek)",
            "https://dev.serpentos.com/protosnek/x86_64/stone.index");
    assert(c.config[0] == testItem);
}

@("Ensure boulder works")
private unittest
{
    auto c = new ProfileConfiguration();
    c.load("../tests");
    assert(c.sections.length == 2);
    auto slocal = Repository("local", "",
            "file:///var/cache/boulder/collections/local/stone.index", 10);
    auto clocal = c.sections[1];
    assert(clocal.collections[1] == slocal);
    writeln(c.sections);
}
