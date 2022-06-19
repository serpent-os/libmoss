/* SPDX-License-Identifier: Zlib */

/**
 * moss.fetcher.result
 *
 * Definition of download results reported by threaded moss fetcher downloads.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.fetcher.result;

public import std.sumtype;

import etc.c.curl;
import std.string : fromStringz;
import core.sys.posix.string : strerror;
import std.string : format;

/**
 * moss-fetcher may have errors from 3 primary domains so we specify them
 * for ease of handling
 */
public enum FetchErrorDomain
{
    CurlEasy = 0,
    CurlShare,
    CStdlib,
}

/**
 * A FetchError is used in a sumtype for matching errors + success without
 * suspending world execution.
 */
public struct FetchError
{
    /**
     * Domain specific error code
     */
    int errorNumber = 0;

    /**
     * Operation domain (curl, etc)
     */
    FetchErrorDomain domain = FetchErrorDomain.CurlEasy;

    /**
     * Corresponding artefact, what caused the error?
     */
    string artifact = null;

    /**
     * Return proper display description for the error
     */
    @property auto toString() const
    {
        final switch (domain)
        {
        case FetchErrorDomain.CurlEasy:
            return format!"[%s] %s: %s"("curl",
                    curl_easy_strerror(errorNumber).fromStringz, artifact);
        case FetchErrorDomain.CurlShare:
            return format!"[%s] %s: %s"("curlShare",
                    curl_share_strerror(errorNumber).fromStringz, artifact);
        case FetchErrorDomain.CStdlib:
            return format!"[%s] %s: %s"("cstdlib",
                    strerror(errorNumber).fromStringz, artifact);
        }
    }
}

/**
 * Algebraic return type for simple coding
 * Contains a status code *or* an error
 */
public alias FetchResult = SumType!(long, FetchError);
