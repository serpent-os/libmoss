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

public import std.typecons : Nullable, nullable;
import core.stdc.errno : ENOENT;
import core.sys.posix.unistd : close;
import std.exception : ErrnoException;
import std.stdio : File;
import std.string : empty, toStringz;

public import moss.core.ioutil : CError;
public import moss.core.c :
    MNT,
    MOUNT_ATTR,
    MS,
    mount_attr;
import cstdlib = moss.core.c;

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
     * mountMode defines how this mount point will be mounted.
     * If unspecified, the kernel will use its default mode.
     */
    cstdlib.MS mountMode;

    /**
     * mountAttr optionally defines additional properties of this mount point.
     * They will be set after the `mount` syscall.
     * If unspecified, the kernel will use its default mode.
     */
    Nullable!(cstdlib.mount_attr) mountAttr;

    /**
     * Default to normal umount flags
     */
    cstdlib.MNT unmountFlags;

    /**
     * Returns: A new tmpfs mount at the given destination
     */
    static Mount tmpfs(in string destination)
    {
        return Mount("", destination, "tmpfs", cstdlib.MS.NONE, cstdlib.mount_attr(cstdlib.MOUNT_ATTR.NODEV).nullable);
    }

    /**
     * Returns: A read-write bind mount from source to destination
     */
    static Mount bindRW(in string source, in string destination)
    {
        return Mount(source, destination, null, cstdlib.MS.BIND);
    }

    /**
     * Returns: A read-only bind mount from source to destination
     */
    static Mount bindRO(in string source, in string destination)
    {
        return Mount(source, destination, null, cstdlib.MS.BIND, cstdlib.mount_attr(cstdlib.MOUNT_ATTR.RDONLY).nullable);
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

        auto ret = cstdlib.mount(fsSource, fsDest, fsType, mountMode, data);
        if (ret != 0)
        {
            return MountReturn(CError(cstdlib.errno));
        }
        if (mountAttr.isNull())
        {
            return MountReturn();
        }
        try
        {
            ret = this.mountSetAttr();
        }
        catch (Exception)
        {
            ret = -1;
        }
        if (ret != 0)
        {
            return MountReturn(CError(cstdlib.errno));
        }
        return MountReturn();
    }

    /**
     * Attempt to unmount this mount point
     */
    MountReturn unmount() @system nothrow const
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

    int mountSetAttr()
    {
        auto fd = cstdlib.open_tree(
            -1,
            target.toStringz(),
            cstdlib.AT.NONE
        );
        if (fd < 0)
        {
            return fd;
        }
        scope(exit)
        {
            close(fd);
        }
        auto attrs = this.mountAttr.get();
        auto ret = cstdlib.mount_setattr(
            fd,
            "".toStringz,
            cstdlib.AT.EMPTY_PATH | cstdlib.AT.RECURSIVE,
            &attrs,
            attrs.sizeof,
        );
        return ret;
    }
}
