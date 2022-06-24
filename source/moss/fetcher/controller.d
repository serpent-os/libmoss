/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.fetcher.controller
 *
 * Controller functionality for threaded moss fetcher downloads.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
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
            auto worker = new FetchWorker(i, pref);
            worker.startFully();
            workers ~= worker;
        }

        /* Allow them to work now */
        foreach (ref worker; workers)
        {
            worker.share = shmem;
            worker.allowWork();
        }

        import std.stdio : writeln, writef;

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
            }, (ProgressReport report) {
                onProgress.emit(report.workerIndex, report.origin,
                    report.downloadTotal, report.downloadCurrent);
            }, (WorkReport report) {
                report.result.match!((long code) {
                    onComplete.emit(report.origin, code);
                }, (FetchError err) {
                    onFail.emit(report.origin, err.toString());
                });
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
     * True if the queue is empty
     */
    pure override bool empty()
    {
        return queue.empty;
    }

    /**
     * Clear the queue
     */
    override void clear()
    {
        queue.clear();
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
    import std.stdio : writef, stdout;
    import std.string : startsWith;

    auto f = new FetchController(4);
    bool gotmake = false;
    void helper(immutable(Fetchable) f, long code)
    {
        gotmake = true;
    }

    auto jobs = [
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/glibc-2.34-1-1-x86_64.stone",
                "glibc-2.34-1-1-x86_64.stone"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/glibc-32bit-2.34-1-1-x86_64.stone",
                "glibc-32bit-2.34-1-1-x86_64.stone"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/binutils-2.37-1-1-x86_64.stone",
                "binutils-2.37-1-1-x86_64.stone"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/curl-7.79.1-1-1-x86_64.stone",
                "curl-7.79.1-1-1-x86_64.stone"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/gcc-32bit-11.2.0-1-1-x86_64.stone",
                "gcc-32bit-11.2.0-1-1-x86_64.stone"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/file-5.4-1-1-x86_64.stone",
                "file-5.4-1-1-x86_64.stone"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/libarchive-3.5.2-1-1-x86_64.stone",
                "libarchive-3.5.2-1-1-x86_64.stone"),
        Fetchable("https://dev.serpentos.com/protosnek/x86_64/make-4.3-1-1-x86_64.stone",
                "make-4.3-1-1-x86_64.stone", 0, FetchType.RegularFile, &helper),
    ];
    foreach (j; jobs)
    {
        if (j.destinationPath.startsWith("glibc-32bit"))
        {
            j.expectedSize = 200;
        }
        else if (j.destinationPath.startsWith("glibc"))
        {
            j.expectedSize = 250;
        }
        else
        {
            j.expectedSize = 0;
        }

        f.enqueue(j);
    }

    void hideCursor()
    {
        writef("\033[?25l");
        stdout.flush();
    }

    void showCursor()
    {
        writef("\033[?25h");
        stdout.flush();
    }

    class Monitor
    {
        uint curRow = 0;

        void onComplete(in Fetchable f, long code)
        {

        }

        void onFail(in Fetchable f, string errorMsg)
        {
            assert(errorMsg);
        }

        this()
        {
            writef!"\n \033[4m%s\033[0m\n\n"("Downloading");
            /* Reserve for 4 renderables */
            foreach (i; 0 .. 4)
            {
                writef("\n");
            }
            /* Move back up to the start */
            writef!"\033[%dA"(4);
        }

        void moveCursor(uint newCursor)
        {
            if (newCursor > curRow)
            {
                /* move down */
                writef!"\033[%dB"(newCursor - curRow);
            }
            else if (newCursor < curRow)
            {
                /* move up */
                writef!"\033[%dA"(curRow - newCursor);
            }
            curRow = newCursor;
        }

        void progress(uint workerIndex, Fetchable f, double dlTotal, double dlCurrent)
        {
            import std.path : baseName;
            import std.math : floor;

            moveCursor(workerIndex);

            const auto numSegments = 10;
            double renderFraction;
            if (dlTotal < dlCurrent || dlTotal == 0)
            {
                renderFraction = 0.0;
            }
            else
            {
                renderFraction = dlCurrent / dlTotal;
            }
            const double renderableSegments = renderFraction * cast(double) numSegments;
            int emptySegments = numSegments - (cast(int) renderableSegments);

            string pbar = "";
            const auto flooredSegments = floor(renderableSegments);
            foreach (i; 0 .. flooredSegments)
            {
                pbar ~= "⬜";
            }

            foreach (i; renderableSegments .. numSegments)
            {
                if (i == renderableSegments && flooredSegments < renderableSegments)
                {
                    pbar ~= "🔲";
                }
                else
                {
                    pbar ~= "⬛";
                }
            }

            writef("\033[1k\r %s %s \033[2m%.2f%%\033[0m          ", pbar,
                    f.sourceURI.baseName, renderFraction * 100.0);

            stdout.flush();
        }
    }

    auto m = new Monitor();
    f.onProgress.connect(&m.progress);
    f.onComplete.connect(&m.onComplete);
    f.onFail.connect(&m.onFail);
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

    hideCursor();
    scope (exit)
    {
        showCursor();
    }
    while (!f.empty())
    {
        f.fetch();
    }
    m.moveCursor(4);
    writef("\n");
    assert(gotmake == true);
    f.close();
}
