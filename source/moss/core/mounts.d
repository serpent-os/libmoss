/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.mounts
 *
 * Mount specific functionality for moss.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.core.mounts;

import cstdlib = moss.core.c;
public import moss.core.ioutil : CError;

public import std.typecons : Nullable;
public import moss.core.c : MountFlags, UnmountFlags;

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
     * What are we mounting .. where?
     */
    string source;

    /**
     * Set the target mount point
     */
    string target;

    /**
     * Set the filesystem type
     */
    string filesystem;

    /** 
     * Default to normal mount flags
     */
    MountFlags mountFlags = MountFlags.None;

    /**
     * Default to normal umount flags
     */
    UnmountFlags unmountFlags = UnmountFlags.None;

    /**
     * Returns: A new tmpfs mount at the given destination
     */
    static Mount tmpfs(in string destination)
    {
        return Mount("tmpfs", destination, "tmpfs", MountFlags.NoDev);
    }

    /**
     * Returns: A read-write bind mount from source to destination
     */
    static Mount bindRW(in string source, in string destination)
    {
        return Mount(source, destination, null, MountFlags.Bind);
    }

    /**
     * Returns: A read-only bind mount from source to destination
     */
    static Mount bindRO(in string source, in string destination)
    {
        return Mount(source, destination, null, MountFlags.Bind | MountFlags.ReadOnly);
    }

    /**
     * Attempt to mount this mount point
     *
     * The required mount point must already exist or this call will fail
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

        /* We need read-only? */
        if ((mountFlags & MountFlags.ReadOnly) != MountFlags.ReadOnly)
        {
            return MountReturn();
        }

        /* Remount read-only, preserve bind-flag */
        auto newFlags = MountFlags.ReadOnly | MountFlags.Remount;
        if ((mountFlags & MountFlags.Bind) == MountFlags.Bind)
        {
            newFlags |= MountFlags.Bind;
        }

        /* Perform the remount */
        ret = cstdlib.mount(fsSource, fsDest, fsType, cast(ulong) newFlags, data);
        if (ret != 0)
        {
            return MountReturn(CError(cstdlib.errno));
        }

        /* All went well */
        return MountReturn();
    }

    /**
     * Attempt to unmount this mount point
     */
    MountReturn unmount() @system nothrow
    {
        scope const char* fsDest = target.empty ? null : target.toStringz;
        auto ret = cstdlib.umount2(fsDest, unmountFlags);
        if (ret != 0)
        {
            return MountReturn(CError(cstdlib.errno));
        }
        return MountReturn();
    }

private:

    /* Always NULL, never used in our implementation */
    static void* data = null;
}
