/*
 * This file is part of moss-deps.
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

module moss.deps.analysis.bucket;

import std.container.rbtree;

/**
 * An AnalysisBucket is created for each subpackage so we know ahead of time
 * which files go where.
 */
public final class AnalysisBucket
{

    @disable this();

    /**
     * Return the bucket name
     */
    pure @property const(string) name() @safe @nogc nothrow
    {
        return _name;
    }

package:

    /**
     * Construct a new AnalysisBucket with the given name
     */
    this(in string name)
    {
        _name = name;
    }

private:

    string _name = null;
}
