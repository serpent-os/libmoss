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

import core.sys.posix.unistd : close;
import std.exception : ErrnoException;

import moss.core.c.mounts : cUnmount = unmount;
public import moss.core.c.mounts;

struct FSConfigValue
{
    FSCONFIG type;
    void* value;
    int aux; /** aux is auxiliary data. May be left uset when unnecessary. */
}

struct FSMount
{
    string filesystem;
    string target;
    FSConfigValue[string] config;
    MS mountFlags = cast(MS) 0;

    void mountDetached()
    {
        auto fd = fsopen(filesystem);
        scope(exit)
        {
            _close(fd);
        }

        foreach (key, val; this.config)
        {
            fsconfig(fd, val.type, key, val.value, val.aux);
        }
        fsconfig(fd, FSCONFIG.CMD_CREATE, "", null);

        this.mountFD = fsmount(fd, cast(FSMOUNT) 0, mountFlags);
    }

    void moveToTarget()
    {
        move_mount(this.mountFD, "", 0, this.target, MOVE_MOUNT.F_EMPTY_PATH);
        _close(this.mountFD);
    }

    /**
     * mount is a convenience method to easily mount the mount point.
     * No extra function calls are required.
     */
    void mount()
    {
        this.mountDetached();
        this.moveToTarget();
    }

    void unmount()
    {
        cUnmount(this.target);
    }

private:
    int mountFD;
}

struct FileMount
{
    string source;
    string target;
    AT openFlags;
    MountAttr attributes;
    MNT unmountFlags;

    /**
     * Returns: A read-write bind mount from source to destination.
     */
    static FileMount bindRW(in string source, in string destination)
    {
        return FileMount(source, destination, cast(AT) OPEN_TREE.CLONE);
    }

    /**
     * Returns: A read-only bind mount from source to destination.
     */
    static FileMount bindRO(in string source, in string destination)
    {
        return FileMount(source, destination, cast(AT) OPEN_TREE.CLONE, MountAttr(MOUNT_ATTR.RDONLY));
    }

    void mountDetached()
    {
        this.fd = open_tree(-1, this.source, this.openFlags | AT.RECURSIVE);
        mount_setattr(this.fd, "", AT.EMPTY_PATH | AT.RECURSIVE, &this.attributes);
    }

    void moveToTarget()
    {
        move_mount(this.fd, "", 0, this.target, MOVE_MOUNT.F_EMPTY_PATH);
        _close(this.fd);
    }

    /**
     * mount is a convenience method to easily mount the mount point.
     * No extra function calls are required.
     */
    void mount()
    {
        this.mountDetached();
        this.moveToTarget();
    }

    void unmount()
    {
        cUnmount(this.target, this.unmountFlags);
    }

private:
    int fd;
}

private:
void _close(int fd)
{
    const auto ret = close(fd);
    if (ret < 0)
    {
        throw new ErrnoException("Failed to close file descriptor");
    }
}
