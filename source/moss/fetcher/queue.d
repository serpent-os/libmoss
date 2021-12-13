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

module moss.fetcher.queue;

import moss.core.fetchcontext : Fetchable;
import std.container.rbtree;

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
