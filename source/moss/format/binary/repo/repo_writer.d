/*
 * This file is part of moss-format.
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

module moss.format.binary.repo.repo_writer;

/**
 * A RepoWriter is responsible for emitting a binary repository to disk.
 * It is not responsible for the management of individual assets on disk,
 * simply for recording a MetaPayload with some attributes in a sequential
 * index.
 *
 * More advanced repo formats will arrive later.
 */
public final class RepoWriter
{
    /**
     * Construct a new RepoWriter
     */
    this(const(string) outputDir) @safe @nogc nothrow
    {
        _outputDir = outputDir;
    }

    /**
     * Return the output directory for the RepoWriter
     */
    pure @property const(string) outputDir() @safe @nogc nothrow
    {
        return _outputDir;
    }

    /**
     * Add a package to the index
     */
    void addPackage(const(string) inpPath, const(string) packageURI)
    {
        import std.stdio : writeln;

        writeln(inpPath, " => ", packageURI);
    }

private:

    string _outputDir = null;
}
