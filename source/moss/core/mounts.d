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

import core.stdc.errno : ENOENT;
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

        auto newFlags = targetMountFlags(this.target);
        if (newFlags < 0)
        {
            return MountReturn(CError(cast(int)(-newFlags)));
        }
        /* Was it a bind mount? If so, pass the bind flag again. */
        newFlags |= MountFlags.Remount | (mountFlags & (MountFlags.Bind | MountFlags.Rec));
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

    /**
     * setData sets additional mounting directives whose
     * context depends on the target file system.
     */
    void setData(immutable(void)* data)
    {
        this.data = data;
    }

private:
    immutable(void)* data = null;
    libmnt_table* mountTable = null;

    /**
     * targetMountFlags returns mount flags for an already-mounted target path,
     * or a negative number on error. The mount flags are OR-ed like they were passed to mount(2).
     * The error, if any, is a negative errno value.
     */
    ulong targetMountFlags(string mountTarget) nothrow
    {
        if (this.mountTable == null)
        {
            this.mountTable = mnt_new_table();
            auto err = mnt_table_parse_mtab(this.mountTable, null);
            if (err < 0)
            {
                return err;
            }
        }
        auto mountPoint = mnt_table_find_target(this.mountTable,
                mountTarget.toStringz(), MNT_ITER_BACKWARD);
        if (mountPoint == null)
        {
            return -ENOENT;
        }
        auto mountOptions = mnt_fs_get_options(mountPoint);
        ulong flags = 0;
        auto err = mnt_optstr_get_flags(mountOptions, &flags,
                mnt_get_builtin_optmap(MNT_LINUX_MAP));
        if (err < 0)
        {
            return err;
        }
        return flags;
    }
}

/* libmount symbols. */
extern (C) nothrow @nogc
{
    struct libmnt_table;
    struct libmnt_fs;
    struct libmnt_optmap;
    enum
    {
        MNT_ITER_FORWARD = 0,
        MNT_ITER_BACKWARD
    };
    enum
    {
        MNT_LINUX_MAP = 1,
        MNT_USERSPACE_MAP
    };

    libmnt_table* mnt_new_table();
    int mnt_table_parse_mtab(libmnt_table* tb, const char* filename);
    libmnt_fs* mnt_table_find_target(libmnt_table* tb, const char* path, int direction);
    immutable(char*) mnt_fs_get_options(libmnt_fs* fs);
    int mnt_optstr_get_flags(const char* optstr, ulong* flags, const libmnt_optmap* map);
    immutable(libmnt_optmap*) mnt_get_builtin_optmap(int id);
}
