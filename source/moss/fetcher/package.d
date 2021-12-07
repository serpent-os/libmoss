/*
 * This file is part of moss-fetcher.
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

module moss.fetcher;

public import moss.fetcher.controller;
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
 */
public alias FetchResult = SumType!(bool, FetchError);
