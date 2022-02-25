/* SPDX-License-Identifier: Zlib */

/**
 * Mount specific functionality
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module moss.core.mounts;

import cstdlib = moss.core.c;
public import moss.core.ioutil : CError;

public import std.typecons : Nullable;

/**
 * A null return from mount/umount/umount2 is "good" for us.
 */
public alias MountReturn = Nullable!(CError, CError.init);

/**
 * Define a mount through a sensible API
 */
public struct Mount
{

    /**
     * Returns: A new tmpfs mount at the given destination
     */
    static Mount tmpfs(in string destination)
    {
        return Mount();
    }

    /**
     * Returns: A read-write bind mount from source to destination
     */
    static Mount bindRW(in string source, in string destination)
    {
        return Mount();
    }

    /**
     * Returns: A read-only bind mount from source to destination
     */
    static Mount bindRO(in string source, in string destination)
    {
        return Mount();
    }
}
