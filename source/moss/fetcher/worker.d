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

module moss.fetcher.worker;

import etc.c.curl;
import core.sync.mutex;

/**
 * The worker preference defines our policy in fetching items from the
 * FetcherQueue, i.e small or big
 */
package enum WorkerPreference
{
    /**
     * This worker prefers small items
     */
    SmallItems = 0,

    /**
     * This worker prefers large items
     */
    LargeItems,
}

/**
 * A FetchWorker is created per thread and maintains its own CURL handles
 */
package final class FetchWorker
{

    @disable this();

    /**
     * Construct a new FetchWorker and setup any associated resources.
     */
    this(CURLSH* shmem, WorkerPreference preference = WorkerPreference.SmallItems)
    {
        assert(shmem !is null);
        this.shmem = shmem;
        this.preference = preference;

        /* Grab a handle. */
        handle = curl_easy_init();

        /* Establish locks for CURLSH usage */
        dnsLock = new shared Mutex();
        sslLock = new shared Mutex();
        conLock = new shared Mutex();
    }

    /**
     * Close down this worker resources
     */
    void close()
    {
        if (handle is null)
        {
            return;
        }
        curl_easy_cleanup(handle);
        handle = null;
    }

    /**
     * Lock a specific mutex for CURL sharing
     */
    void lock(CurlLockData lockData) @safe @nogc nothrow
    {
        switch (lockData)
        {
        case CurlLockData.dns:
            dnsLock.lock_nothrow();
            break;
        case CurlLockData.ssl_session:
            sslLock.lock_nothrow();
            break;
        case CurlLockData.connect:
            conLock.lock_nothrow();
            break;
        default:
            break;
        }
    }

    /**
     * Unlock a specific mutex for CURL sharing
     */
    void unlock(CurlLockData lockData) @safe @nogc nothrow
    {
        switch (lockData)
        {
        case CurlLockData.dns:
            dnsLock.unlock_nothrow();
            break;
        case CurlLockData.ssl_session:
            sslLock.unlock_nothrow();
            break;
        case CurlLockData.connect:
            conLock.unlock_nothrow();
            break;
        default:
            break;
        }
    }

private:

    /**
     * Reusable handle
     */
    CURL* handle;

    /**
     * Shared data for CURL handles
     */
    CURLSH* shmem;

    /**
     * Lock for sharing DNS
     */
    shared Mutex dnsLock;

    /**
     * Lock for sharing SSL session
     */
    shared Mutex sslLock;

    /**
     * Lock for sharing connections
     */
    shared Mutex conLock;

    /**
     * By default prefer small items
     */
    WorkerPreference preference = WorkerPreference.SmallItems;
}
