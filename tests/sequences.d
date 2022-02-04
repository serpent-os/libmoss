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
import std.stdio : writeln;

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
    auto n = new Snippet!OurConfig;
    n.load("../tests/sequence_structs.yml");
}

