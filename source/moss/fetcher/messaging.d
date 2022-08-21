/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.fetcher.messaging
 *
 * Thread message definitions for moss fetcher functionality.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.fetcher.messaging;

import std.concurrency : Tid;
import moss.core.fetchcontext;
import moss.fetcher.worker : WorkerPreference;
import moss.fetcher.result;

@trusted:

/**
 * Acknowledgement startup completed
 */
package struct StartupAck
{

}

/**
 * Shut down request
 */
package struct ShutdownControl
{
}

/**
 * Shutdown acknowledgement
 */
package struct ShutdownAck
{
}

/**
 * Requesting work for our thread
 */
package struct AllocateFetchableControl
{
    Tid origin;
    WorkerPreference preference = WorkerPreference.SmallItems;
}

/**
 * Unblock the thread now that startup coordination is complete
 */
package struct AllowWorkControl
{
}

/**
 * WorkReport contains the fetchable that spawned the FetchResult as
 * well as the result itself.
 */
package struct WorkReport
{
    Fetchable origin;
    FetchResult result;
}

/**
 * Worker sends progress reports (throttled) to allow knowing where we're at
 * with the downloads..
 */
package struct ProgressReport
{
    /**
     * The current work package
     */
    Fetchable origin;

    /**
     * Worker index, to permit 0-N progressbars
     */
    uint workerIndex = 0;

    /**
     * Total to download
     */
    double downloadTotal = 0.0;

    /**
     * How much we've downloaded so far
     */
    double downloadCurrent = 0.0;
}
