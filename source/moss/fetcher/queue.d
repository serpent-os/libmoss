/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.fetcher.queue
 *
 * Queue functionality for threaded moss fetcher downloads.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.fetcher.queue;

import moss.core.fetchcontext : Fetchable;
import std.container.rbtree;

@trusted:

/**
 * Specialist dequeue helper to automatically sort the Fetchables into
 * largest and smallest calls, whilst grouping by URI for connection reuse.
 * This class performs no synchronisation itself, it is instead handled by
 * each worker.
 */
package final class FetchQueue
{

    /**
     * Create a new FetchQueue
     */
    this()
    {
        tree = new FetchTree();
    }

    /**
     * Pop the front element from the queue, which
     * is the smallest element known
     */
    auto popFront()
    {
        auto f = tree.front;
        tree.removeFront();
        return f;
    }

    alias popSmallest = popFront;

    /**
     * Pop the rear element of the queue, which is
     * the largest element known.
     */
    auto popBack()
    {
        auto f = tree.back;
        tree.removeBack();
        return f;
    }

    alias popLargest = popBack;

    /**
     * Add a fetchable to the internal queue
     */
    void enqueue(in Fetchable f)
    {
        tree.insert(f);
    }

    /**
     * Return true if this queue is empty
     */
    pure bool empty() const
    {
        return tree.empty;
    }

    /**
     * Clear the queue
     */
    void clear()
    {
        tree.clear();
    }

private:

    /* Sort by size, group by origin */
    alias FetchTree = RedBlackTree!(Fetchable, (a, b) => a.expectedSize != b.expectedSize
            ? a.expectedSize < b.expectedSize : a.sourceURI < b.sourceURI, false);

    FetchTree tree;
}
