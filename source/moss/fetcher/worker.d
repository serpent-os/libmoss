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
import std.exception : enforce;
import moss.fetcher.controller : FetchController;
import moss.core.fetchcontext : Fetchable, FetchType;
import moss.fetcher : NullableFetchable;
import moss.fetcher.messaging;
import moss.fetcher.result;
import std.string : toStringz;
import std.sumtype;
import core.thread.osthread;
import std.datetime;
import cstdlib = moss.core.c;
import moss.core.ioutil;

import std.concurrency : locate, Tid, thisTid, receiveOnly, receive, send;

/**
 * We permit a message every 10 ms (100hz)
 */
static const auto throttleDuration = 10.msecs;

/**
 * The worker preference defines our policy in fetching items from the
 * FetchQueue, i.e small or big
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
package final class FetchWorker : Thread
{

    @disable this();

    /**
     * Construct a new FetchWorker and setup any associated resources.
     */
    this(uint workerIndex, WorkerPreference preference = WorkerPreference.SmallItems)
    {
        super(&processLoop);
        this.workerIndex = workerIndex;
        this.preference = preference;
        throttleMarker = Clock.currTime();

        /* Grab a handle. */
        handle = curl_easy_init();
        enforce(handle !is null, "FetchWorker(): curl_easy_init() failure");
        setupHandle();
    }

    /**
     * Ensure we get a full startup.
     */
    void startFully()
    {
        start();
        receiveOnly!StartupAck;
    }

    void allowWork()
    {
        send(ourTid, AllowWorkControl());
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
        send(ourTid, ShutdownControl());
        receiveOnly!ShutdownAck;
        join();

        curl_easy_cleanup(handle);
        handle = null;
    }

    /**
     * Set the CURLSH share property
     */
    @property void share(CURLSH* share)
    {
        shmem = share;

        /* Setup share */
        auto ret = curl_easy_setopt(handle, CurlOption.share, shmem);
        enforce(ret == CurlError.ok, "FetchWorker.setupHandle(): Failed to set SHARE");
    }

private:

    /**
     * Main thread body
     */
    void processLoop()
    {
        mainThread = locate("fetchController");
        ourTid = thisTid();

        /* startupFully() now complete, we're known to be running */
        send(mainThread, StartupAck());

        receiveOnly!AllowWorkControl;

        /* Main loop here */
        while (true)
        {
            send(mainThread, AllocateFetchableControl(ourTid, preference));
            auto job = receiveOnly!NullableFetchable;
            /* No job. Get outta here */
            if (job.isNull)
            {
                break;
            }

            /* Process the job and send completion status.. */
            auto fetchable = job.get;
            auto result = process(fetchable);
            send(mainThread, WorkReport(fetchable, result));
        }

        /* Block for shutdown + join */
        receiveOnly!ShutdownControl;
        send(mainThread, ShutdownAck());
    }

    /**
     * Process a single fetchable
     */
    FetchResult process(ref Fetchable fetchable)
    {
        CURLcode ret;
        CError foundError;
        throttleMarker = Clock.currTime();

        final switch (fetchable.type)
        {
        case FetchType.RegularFile:
            outputFD = IOUtil.create(fetchable.destinationPath)
                .match!((int fd) => fd, (err) { foundError = err; return -1; });
            break;
        case FetchType.TemporaryFile:
            outputFD = IOUtil.createTemporary(fetchable.destinationPath).match!((TemporaryFile t) {
                fetchable.destinationPath = t.realPath;
                return t.fd;
            }, (err) { foundError = err; return -1; });
            break;
        }

        /* Make sure we can continue now */
        if (outputFD < 0)
        {
            return FetchResult(FetchError(foundError.errorCode,
                    FetchErrorDomain.CStdlib, fetchable.destinationPath));
        }

        /* Ensure we close the file again */
        scope (exit)
        {
            cstdlib.close(outputFD);
            outputFD = -1;
        }

        /* Set up the URL */
        ret = curl_easy_setopt(handle, CurlOption.url, fetchable.sourceURI.toStringz);
        if (ret != CurlError.ok)
        {
            return FetchResult(FetchError(ret, FetchErrorDomain.CurlEasy, fetchable.sourceURI));
        }

        /* try to download now */
        ret = curl_easy_perform(handle);
        if (ret != CurlError.ok)
        {
            return FetchResult(FetchError(ret, FetchErrorDomain.CurlEasy, fetchable.sourceURI));
        }

        long statusCode = 0;
        curl_easy_getinfo(handle, CurlInfo.response_code, &statusCode);

        /* Force the total to 100 now */
        double dltotal = 0;
        curl_easy_getinfo(handle, CurlInfo.size_download, &dltotal);
        reportProgress(dltotal, dltotal, true);

        /* All went well? */
        return FetchResult(statusCode);
    }

    /**
     * Set the baseline handle options
     */
    void setupHandle()
    {
        CURLcode ret;

        /* Setup write callback */
        ret = curl_easy_setopt(handle, CurlOption.writefunction, &mossFetchWorkerWrite);
        enforce(ret == CurlError.ok, "FetchWorker.setupHandle(): Failed to set WRITEFUNCTION");
        ret = curl_easy_setopt(handle, CurlOption.writedata, this);
        enforce(ret == CurlError.ok, "FetchWorker.setupHandle(): Failed to set WRITEDATA");

        /* Setup progress callback */
        ret = curl_easy_setopt(handle, CurlOption.progressfunction, &mossFetchWorkerProgress);
        enforce(ret == CurlError.ok, "FetchWorker.setupHandle(): Failed to set PROGRESSFUNCTION");
        ret = curl_easy_setopt(handle, CurlOption.progressdata, this);
        enforce(ret == CurlError.ok, "FetchWorker.setupHandle(): Failed to set PROGRESSDATA");

        /* Enable progress reporting */
        ret = curl_easy_setopt(handle, CurlOption.noprogress, 0);
        enforce(ret == CurlError.ok, "FetchWorker.setupHandle(): Failed to set NOPROGRESS");
    }

    /**
     * Report progress back to the main thread
     */
    void reportProgress(double dlTotal, double dlNow, bool forceUpdate = false)
    {
        /* Throttle the updates */
        auto timenow = Clock.currTime();
        SysTime timeold = throttleMarker + throttleDuration;
        if (timenow < timeold && !forceUpdate)
        {
            return;
        }
        throttleMarker = timenow;
        auto msg = ProgressReport(currentWork, workerIndex, dlTotal, dlNow);
        send(mainThread, msg);
    }

    /**
     * Handle writing
     */
    extern (C) static size_t mossFetchWorkerWrite(void* ptr, size_t size,
            size_t nMemb, void* userptr)
    {
        auto worker = cast(FetchWorker) userptr;
        enforce(worker !is null, "CURL IS BROKEN");
        enforce(worker.outputFD >= 0, "FetchWorker: Invalid file descriptor");

        /* Write the file now */
        import core.sys.posix.unistd : write;

        return write(worker.outputFD, ptr, nMemb);
    }

    /**
     * Handle the progress callback
     */
    extern (C) static size_t mossFetchWorkerProgress(void* userptr,
            double dlTotal, double dlNow, double ulTotal, double ulNow)
    {
        auto worker = cast(FetchWorker) userptr;
        enforce(worker !is null, "CURL IS BROKEN");
        worker.reportProgress(dlTotal, dlNow);
        return 0;
    }

    /**
     * Reusable handle
     */
    CURL* handle;

    /**
     * CURLSH handle
     */
    CURLSH* shmem;

    /**
     * By default prefer small items
     */
    WorkerPreference preference = WorkerPreference.SmallItems;

    /**
     * Our thread ID
     */
    Tid ourTid;

    /**
     * Controller
     */
    Tid mainThread;

    /**
     * Current fetchable that we're working on
     */
    Fetchable currentWork;

    /**
     * Storage
     */
    int outputFD = -1;

    /**
     * Which worker are we?
     */
    uint workerIndex = 0;

    /**
     * Allow throttling progress reports
     */
    SysTime throttleMarker;
}
