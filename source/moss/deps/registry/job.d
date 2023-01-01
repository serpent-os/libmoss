/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.registry.job
 *
 * Job abstraction for fetchable/installable thingies.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.registry.job;

public import std.stdint : uint64_t;

/**
 * Specific job *type*
 */
public enum JobType
{
    /**
     * We're refreshing a single repository
     */
    RefreshRepository,

    /**
     * We're fetching a single package.
     */
    FetchPackage,
}

/**
 * Specific status of the job
 */
public enum JobStatus
{
    Pending,
    InProgress,
    Failed,
    Completed,
}

/**
 * A Job is our abstraction of the fetching system to
 * allow manipulation and persistence of state.
 */
public final class Job
{

    @disable this();

    /**
     * Construct a new Job with the given type and identifier
     *
     * Params:
     *      type = Job type
     *      id = Unique identifier (pkgID or remote ID)
     */
    this(JobType type, string id) @safe
    {
        _type = type;
        _id = id;
    }

    /**
     * Specific job type
     *
     * Returns: the job type
     */
    pure @property JobType type() @safe @nogc nothrow const
    {
        return _type;
    }

    /**
     * Identifier (pkgID or remote ID)
     *
     * Returns: the unique identifier
     */
    pure @property auto id() @safe @nogc nothrow const
    {
        return _id;
    }

    /**
     * Remote URI to be fetched
     *
     * Returns: the remote URI
     */
    pure @property auto remoteURI() @safe @nogc nothrow const
    {
        return _remoteURI;
    }

    /**
     * Set the remote URI
     *
     * Params:
     *      s = New remote URI
     */
    pure @property void remoteURI(string s) @safe
    {
        _remoteURI = s;
    }

    /**
     * Download location on disk
     *
     * Returns: The download location
     */
    pure @property auto destinationPath() @safe @nogc nothrow const
    {
        return _destinationPath;
    }

    /**
     * Download location on disk
     *
     * Params:
     *      s = New download location
     */
    pure @property void destinationPath(string s) @safe
    {
        _destinationPath = s;
    }

    /**
     * Checksum for verification
     *
     * Returns: Checksum
     */
    pure @property auto checksum() @safe @nogc nothrow const
    {
        return _checksum;
    }

    /**
     * Checksum for verification
     *
     * Params:
     *      s = New checksum
     */
    pure @property void checksum(string s) @safe
    {
        _checksum = s;
    }

    /**
     * Job status
     *
     * Returns: the job status
     */
    pure @property auto status() @safe @nogc nothrow const
    {
        return _status;
    }

    /**
     * Job status
     *
     * Params:
     *      s = new job status
     */
    pure @property void status(JobStatus s) @safe
    {
        _status = s;
    }

    /**
     * Expected size
     *
     * Returns: expected download size
     */
    pure @property auto expectedSize() @safe @nogc nothrow const
    {
        return _expectedSize;
    }

    /**
     * Expected size
     *
     * Params:
     *      s = New expected size
     */
    pure @property void expectedSize(uint64_t s) @safe @nogc nothrow
    {
        _expectedSize = s;
    }

private:

    JobType _type;
    string _id;
    string _remoteURI;
    string _destinationPath;
    string _checksum;
    uint64_t _expectedSize = 0;
    JobStatus _status = JobStatus.Pending;
}
