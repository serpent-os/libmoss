/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.fetcher.worker
 *
 * Defines worker functionality for moss fetcher download threads.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.fetcher.worker;

import etc.c.curl;
import std.exception : enforce;
import moss.fetcher.controller : FetchController;
import moss.core.fetchcontext : Fetchable, FetchableClosure, FetchType;
import moss.fetcher : NullableFetchable;
import moss.fetcher.messaging;
import moss.fetcher.result;
import std.string : toStringz;
import std.sumtype;
import core.thread.osthread;
import std.datetime;
import cstdlib = moss.core.c;
import moss.core.ioutil;
import std.stdint : uint64_t;

version (libgit2) import git2;

import std.concurrency : locate, Tid, thisTid, receiveOnly, receive, send;

@trusted:

/**
 * We permit a message every 100 ms (10hz)
 */
static const auto throttleDuration = 100.msecs;

/**
 * Provided because we need to emit a usable Fetchable struct but we can't
 * permit unshared aliasing.
 */
private struct FetchCopy
{
    string sourceURI;
    string destinationPath;
    uint64_t expectedSize;
    FetchType type;
    FetchableClosure onComplete;

    static pure FetchCopy fromFetchable(in Fetchable f) @safe @nogc nothrow
    {
        return FetchCopy(f.sourceURI, f.destinationPath, f.expectedSize, f.type, f.onComplete);
    }

    pure Fetchable toFetchable() @safe @nogc nothrow
    {
        return Fetchable(sourceURI, destinationPath, expectedSize, type, onComplete);
    }
}

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

        version (libgit2)
        {
            /* Initialize libgit2 */
            int err = git_libgit2_init();
            enforce(err >= 0, "FetchWorker(): git_libgit2_init() failure");
        }
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

        version (libgit2)
        {
            /* Just quitting is too severe, maybe warning is better */
            int err = git_libgit2_shutdown();
            enforce(err >= 0, "FetchWorker(): git_libgit2_shutdown() failure");
        }
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
            currentWork = FetchCopy.fromFetchable(fetchable);
            auto result = process(fetchable);

            /* Invoke closure within our thread */
            if (fetchable.onComplete !is null)
            {
                result.match!((long code) {
                    fetchable.onComplete(cast(immutable(Fetchable)) fetchable, code);
                }, (FetchError err) {});
            }
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
        import std.file : exists, mkdirRecurse;
        import std.path : dirName;

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
        case FetchType.GitRepository:
        case FetchType.GitRepositoryMirror:
            if (!fetchable.destinationPath.dirName.exists())
            {
                fetchable.destinationPath.dirName.mkdirRecurse();
            }
            break;
        }

        bool isGitType = fetchable.type == FetchType.GitRepository
            || fetchable.type == FetchType.GitRepositoryMirror;

        /* Make sure we can continue now */
        if (!isGitType && outputFD < 0)
        {
            return FetchResult(FetchError(foundError.errorCode,
                    FetchErrorDomain.CStdlib, fetchable.destinationPath));
        }

        /* Ensure we close the file again */
        scope (exit)
        {
            if (isGitType)
            {
                cstdlib.close(outputFD);
                outputFD = -1;
            }
        }

        long statusCode = 0;

        /* Clone requested the repository. */
        if (isGitType)
        {
            version (libgit2)
            {
                import core.stdc.stdio;
                import std.logger;

                scope git_repository* repo;
                scope (exit)
                    git_repository_free(repo);
                scope git_remote* remote;
                scope (exit)
                    git_remote_free(remote);

                git_fetch_options fetch_opts;
                fetch_opts.git_fetch_init_options(GIT_FETCH_OPTIONS_VERSION);
                fetch_opts.callbacks.transfer_progress = &mossGitFetchWorkerProgress;
                fetch_opts.callbacks.payload = (() @trusted => cast(void*) this)();

                // Create, init, and setup the remote for a new repository if
                // there isn't one already at the destination path.
                if (!fetchable.destinationPath.exists())
                {
                    mkdirRecurse(fetchable.destinationPath);

                    if (repo.git_repository_init(fetchable.destinationPath.toStringz(),
                            fetchable.type == FetchType.GitRepositoryMirror))
                    {
                        debug fprintf(stderr, "Failed to init repository at %s, reason: %s\n",
                                fetchable.destinationPath.toStringz(), git_error_last().message);
                        return FetchResult(FetchError(git_error_last().klass,
                                FetchErrorDomain.Git, fetchable.sourceURI));
                    }

                    if (git_remote_create_with_fetchspec(&remote, repo, toStringz("origin"),
                            fetchable.sourceURI.toStringz(), toStringz("+refs/*:refs/*")))
                    {
                        debug fprintf(stderr, "Failed to create remote %s for repository at %s, reason: %s\n",
                                fetchable.sourceURI.toStringz(),
                                fetchable.destinationPath.toStringz(), git_error_last().message);
                        return FetchResult(FetchError(git_error_last().klass,
                                FetchErrorDomain.Git, fetchable.sourceURI));
                    }
                }

                if (git_remote_fetch(remote, null, fetch_opts))
                {
                    debug fprintf(stderr, "Failed to fetch remote for repository at %s, reason: %s\n",
                            fetchable.destinationPath.toStringz(), git_error_last().message);
                    return FetchResult(FetchError(git_error_last().klass,
                            FetchErrorDomain.Git, fetchable.sourceURI));
                }

                /**
                 * Note that we need to return a status code as if we're doing HTTP
                 * requests, so we should return 200 when the command succeeds.
                 */
                if (statusCode == 0)
                {
                    statusCode = 200;
                }
            }
        }
        else
        {
            /* Allow redirection */
            ret = curl_easy_setopt(handle, CurlOption.followlocation, 1);
            if (ret != CurlError.ok)
            {
                return FetchResult(FetchError(ret, FetchErrorDomain.CurlEasy, fetchable.sourceURI));
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

            curl_easy_getinfo(handle, CurlInfo.response_code, &statusCode);

            /* Force the total to 100 now */
            double dltotal = 0;
            curl_easy_getinfo(handle, CurlInfo.size_download, &dltotal);
            reportProgress(dltotal, dltotal, true);
        }

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

        /* No user-agent results in 403 on certain mirrors */
        ret = curl_easy_setopt(handle, CurlOption.useragent, "moss-fetcher/0.1".toStringz);
        enforce(ret == CurlError.ok, "FetchWorker.setupHandle(): Failed to set USERAGENT");

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
        auto msg = ProgressReport(currentWork.toFetchable(), workerIndex, dlTotal, dlNow);
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

    version (libgit2)
    {
        /**
         * Handle the progress callback for Git clones/fetch
         */
        extern (C) static int mossGitFetchWorkerProgress(const(git_indexer_progress)* stats,
                void* payload)
        {
            /**
             * For now there's no way to display two progress bars one after the
             * other,
             * I think. Ideally we want the first progress bar to display
             * received_objects, and after the first bar is finished, the second
             * progress bar would display indexed_deltas. For now, let's just
             * display indexed_objects since it's a sum of the first two.
             */
            auto worker = cast(FetchWorker) payload;
            enforce(worker !is null, "GIT IS BROKEN");
            worker.reportProgress(stats.total_objects, stats.indexed_objects);
            return 0;
        }
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
    FetchCopy currentWork;

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
