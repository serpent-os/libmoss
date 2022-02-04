/* SPDX-License-Identifier: Zlib */

/**
 * Nested sequence tests
 *
 * Simple use-case moss-config testing
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module simple;

import moss.config.io;
import std.stdio : stderr, writeln;

struct Person
{
    string id;
    alias name = id;

    int age = 0;

    string[] interests;

}

struct OurConfig
{
    string mainKey = "oops not set";
    Person[] people;
}

@("Primitive testing")
unittest
{
    auto n = new Snippet!OurConfig("../tests/sequence_structs.yml");
    n.load();
    OurConfig requiredMatch = OurConfig("mainValue", [
            Person("Bob", 40, ["Working", "Sleeping"]),
            Person("Rupert", 0, ["Sleeping", "Sleeping"])
            ]);
    assert(n.config == requiredMatch);
    stderr.writeln(n.config);
}
