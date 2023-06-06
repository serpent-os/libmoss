/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Nested sequence tests
 *
 * Simple use-case moss-config testing
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
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

@ConfigurationDomain("moss", "sequences")
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

@("Layered config testing")
unittest
{
    auto config = new Configuration!OurConfig();
    config.load("../tests");
    OurConfig requiredMatch = OurConfig("001122", [
            Person("Person_A", 22, ["Programming"]),
            Person("Person_B", 25, ["Skiing", "Walking"]),
            ]);
    assert(config.config == requiredMatch);
}
