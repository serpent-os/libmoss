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

import std.string : empty, toStringz;

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
     * Set the filesystem type
     */
    string filesystem;

    /**
     * Set the target mount point
     */
    string target;

    /**
     * What are we mounting .. where?
     */
    string source;

    /** 
     * Default to normal mount flags
     */
    cstdlib.MountFlags mountFlags = cstdlib.MountFlags.None;

    /**
     * Default to normal umount flags
     */
    cstdlib.UnmountFlags unmountFlags = cstdlib.UnmountFlags.None;

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

    /**
     * Attempt to mount this mount point
     */
    MountReturn mount() @system nothrow
    {
        scope const char* fsType = filesystem.empty ? null : filesystem.toStringz;
        scope const char* fsSource = source.empty ? null : source.toStringz;
        scope const char* fsDest = target.empty ? null : target.toStringz;

        auto ret = cstdlib.mount(fsSource, fsDest, fsType, cast(ulong) mountFlags, data);
        if (ret != 0)
        {
            return MountReturn(CError(cstdlib.errno));
        }
        return MountReturn();
    }

    /**
     * Attempt to unmount this mount point
     */
    MountReturn unmount() @system @nogc nothrow
    {
        return MountReturn();
    }

private:

    /* Always NULL, never used in our implementation */
    static void* data = null;
}
