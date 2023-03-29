/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.fetchcontext
 *
 * A FetchContext is responsible for queuing + downloading assets in the form
 * of Fetchables.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.core.fetchcontext;

public import std.stdint : uint64_t;
public import std.signals;

@trusted:

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

    /**
     * Cloning a non-bare repository.
     */
    GitRepository,

    /**
     * Mirror cloning (`git clone --mirror`) a Git repository.
     */
    GitRepositoryMirror,
}

/**
 * The Fetchable's closure is run on the corresponding thread when a fetch
 * has completed. This permits some level of thread architecture reuse for
 * various tasks (check hashsums, etc.)
 */
alias FetchableClosure = void delegate(immutable(Fetchable) fetch, long statusCode);

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

    /**
     * Run this hook when completed.
     */
    immutable(FetchableClosure) onComplete = null;
}

/**
 * A FetchContext will be provided by the implementation and is responsible for
 * queuing + downloading assets. The interface is provided to pass to plugins so
 * they can enqueue their own fetchables without having to know the internal
 * details.
 */
public abstract class FetchContext
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

    /**
     * Return true if the context is now empty. This allows
     * a constant loop approach to using the FetchContext.
     */
    bool empty();

    /**
     * Clear all pending downloads that aren't already in progress
     */
    void clear();

    /**
     * Thread Index (0-N)
     * Fetchable (work unit)
     * Download Total
     * Download Current
     */
    mixin Signal!(uint, Fetchable, double, double) onProgress;

    /**
     * A given fetchable has now completed
     */
    mixin Signal!(Fetchable, long) onComplete;

    /**
     * A given fetchable failed to download
     * Implementations may choose to enqueue the download again
     */
    mixin Signal!(Fetchable, string) onFail;
}
