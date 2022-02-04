/* SPDX-License-Identifier: Zlib */

/**
 * Basic moss-config tests
 *
 * Simple use-case moss-config testing
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module simple;

import moss.config.io;
import moss.config.repo;
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
