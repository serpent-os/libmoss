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

module moss.fetcher.controller;

import etc.c.curl;
import moss.fetcher : NullableFetchable;
import moss.fetcher.queue;
import moss.fetcher.worker;
import moss.fetcher.result;
import std.concurrency : register, thisTid, receive, send;
import moss.fetcher.messaging;
import std.exception : enforce;
import std.parallelism : task, totalCPUs, TaskPool;
import std.range : iota;
import std.algorithm : each, map;
import core.sync.mutex;

public import moss.core.fetchcontext;

/**
 * A fairly simple implementation of the FetchContext. Downloads added to
 * this fetcher are subject to sorting by *expected size* and grouped by
 * their URI.
 *
 * The largest pending downloads will typically download on the main thread
 * while the remaining threads will gobble up all the small jobs, hopefully
 * leading to better distribution.
 *
 * In a lame attempt at optimisation we support connection reuse as well as
 * sharing the shmem cache between curl handles (CURLSH)
 */
public final class FetchController : FetchContext
{
    /**
     * Construct a new FetchController with the given number of worker thread
     */
    this(uint nWorkers = totalCPUs() - 1)
    {
        /* Ensure we always have at LEAST 1 worker */
        if (nWorkers < 1)
        {
            nWorkers = 1;
        }

        foreach (i; 0 .. cast(int) CurlLockData.last)
        {
            locks[i] = new Mutex();
        }

        this.nWorkers = nWorkers;
        shmem = curl_share_init();
        enforce(shmem !is null, "FetchController(): curl_share_init() failure");

        queue = new FetchQueue();

        /* Bind sharing now */
        setupShare();

        register("fetchController", thisTid());
    }

    /**
     * Enqueue a fetchable for future processing
     */
    override void enqueue(in Fetchable f)
    {
        queue.enqueue(f);
    }

    /**
     * For every download currently enqueued, process them all and
     * return from this function when done.
     */
    override void fetch()
    {
        FetchWorker[] workers;
        ulong livingWorkers = nWorkers;

        /* Create N workers, worker 0 preferring large items first */
        foreach (i; 0 .. nWorkers)
        {
            auto pref = i == 0 ? WorkerPreference.LargeItems : WorkerPreference.SmallItems;
            auto worker = new FetchWorker(pref);
            worker.startFully();
            workers ~= worker;
        }

        /* Allow them to work now */
        foreach (ref worker; workers)
        {
            worker.share = shmem;
            worker.allowWork();
        }

        import std.stdio : writeln;

        /* While workers live, let them get null responses */
        while (livingWorkers > 0)
        {
            receive((AllocateFetchableControl msg) {

                auto work = allocateWork(msg.preference);
                send(msg.origin, work);
                if (work.isNull)
                {
                    livingWorkers--;
                }
            }, (WorkReport report) {
                report.result.match!((long code) {
                    writeln("got :", report.origin.sourceURI, " - ", code);
                }, (FetchError err) { writeln("onoes: ", err.toString); });
            });
        }

        /* Free the workers again */
        foreach (ref worker; workers)
        {
            worker.close();
            worker.destroy();
        }
    }

    /**
     * Close this fetcher and any associated resources
     */
    void close()
    {
        if (shmem is null)
        {
            return;
        }

        /* Destroy curl share */
        curl_share_cleanup(shmem);
        shmem = null;
    }

package:

    /**
     * Allocate work for a worker according to their own work preference.
     * If no more work is available, the returned type will return true
     * in isNull
     */
    NullableFetchable allocateWork(WorkerPreference preference)
    {
        if (queue.empty)
        {
            return NullableFetchable();
        }
        return NullableFetchable(preference == WorkerPreference.LargeItems
                ? queue.popLargest : queue.popSmallest);
    }

private:

    /**
     * Setup the sharing aspects
     */
    void setupShare()
    {
        CURLSHcode ret;

        /* We want to share DNS, SSL session and connection pool */
        static auto wanted = [
            CurlLockData.dns, CurlLockData.ssl_session, CurlLockData.connect
        ];

        foreach (w; wanted)
        {
            ret = curl_share_setopt(shmem, CurlShOption.share, w);
            enforce(ret == CurlError.ok,
                    "FetchController.setupShare(): Failed to set CURLSH option");
        }

        /* Set up locking behaviour */
        ret = curl_share_setopt(shmem, CurlShOption.userdata, this);
        enforce(ret == CurlError.ok, "FetchController.setupShare(): Failed to set lock userdata");
        ret = curl_share_setopt(shmem, CurlShOption.lockfunc, &mossFetchControllerLockFunc);
        enforce(ret == CurlError.ok, "FetchController.setupShare(): Failed to set lock function");
        ret = curl_share_setopt(shmem, CurlShOption.unlockfunc, &mossFetchControllerUnlockFunc);
        enforce(ret == CurlError.ok, "FetchController.setupShare(): Failed to set unlock function");
    }

    /**
     * Curl requested we lock something
     */
    extern (C) static void mossFetchControllerLockFunc(void* handle,
            CurlLockData data, CurlLockAccess lockType, void* userptr)
    {
        auto fetcher = cast(FetchController) userptr;
        fetcher.locks[data].lock();
    }

    /**
     * Curl requested we unlock something
     */
    extern (C) static void mossFetchControllerUnlockFunc(void* handle,
            CurlLockData data, CurlLockAccess lockType, void* userptr)
    {
        auto fetcher = cast(FetchController) userptr;
        fetcher.locks[data].unlock();
    }

    /**
     * Shared data for CURL handles
     */
    CURLSH* shmem;

    uint nWorkers = 1;
    FetchQueue queue = null;

    __gshared Mutex[CurlLockData.last] locks;
}

private unittest
{
    auto f = new FetchController(4);
    auto jobs = [
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/binutils-2.37-1-1-x86_64.stone",
                "binutils"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/curl-7.79.1-1-1-x86_64.stone",
                "curl"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/gcc-32bit-11.2.0-1-1-x86_64.stone", "gcc-32bit"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/file-5.4-1-1-x86_64.stone", "file"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/libarchive-3.5.2-1-1-x86_64.stone", "libarchive"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/make-4.3-1-1-x86_64.stone",
                "make"),
    ];
    foreach (j; jobs)
    {
        f.enqueue(j);
    }

    scope (exit)
    {
        /* Cleanup */
        foreach (j; jobs)
        {
            import std.file : remove, exists;

            if (!j.destinationPath.exists)
            {
                continue;
            }
            j.destinationPath.remove();
        }
    }

    f.fetch();
    f.close();
}
