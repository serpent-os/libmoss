/*
 * This file is part of moss-core.
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

module moss.core.fetchcontext;

public import std.stdint : uint64_t;

public enum FetchType
{
    /**
     * Just a regular download
     */
    RegularFile = 0,

    /**
     * Specifically need a temporary file. Use mkstemp() format for the
     * destination path and remember to read it back again
     */
    TemporaryFile,
}

/**
 * A Fetchable simply describes something we need to download.
 */
public struct Fetchable
{
    /**
     * Where are we downloading this thing from?
     */
    string sourceURI = null;

    /**
     * Where are we storing it?
     */
    string destinationPath = null;

    /**
     * Expected size for the fetchable. Used for organising the
     * downloads by domain + size.
     */
    uint64_t expectedSize = uint64_t.max;

    /**
     * Regular download or needing tmpfs?
     */
    FetchType type = FetchType.RegularFile;
}

/**
 * A FetchContext will be provided by the implementation and is responsible for
 * queuing + downloading assets. The interface is provided to pass to plugins so
 * they can enqueue their own fetchables without having to know the internal
 * details.
 */
public interface FetchContext
{
    /**
     * Enqueue some download
     */
    void enqueue(in Fetchable f);

    /**
     * The implementation should block until all
     * downloads have been attempted and the backlog
     * cleared.
     */
    void fetch();
}
