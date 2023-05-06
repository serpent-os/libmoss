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

import moss.core.c.mounts;
import moss.core.c.mounts : cUnmount = unmount;

struct FSConfigValue
{
    FSCONFIG type;
    void* value;
}

struct FSMount
{
    string filesystem;
    string target;
    FSConfigValue[string] config;
    MS mountFlags;

    void create()
    {
        this.fd = fsopen(filesystem);
    }

    void configure()
    {
        foreach (key, val; this.config)
        {
            fsconfig(this.fd, val.type, key, val.value);
        }
        fsconfig(this.fd, FSCONFIG.CMD_CREATE, "", null);
    }

    void mountDetached()
    {
        this.mountFD = fsmount(this.fd, cast(FSMOUNT) 0, mountFlags);
    }

    void mountToTarget()
    {
        move_mount(this.mountFD, "", 0, this.target, MOVE_MOUNT.F_EMPTY_PATH);
    }

    /**
     * mount is a convenience method to easily mount the mount point.
     * No extra function calls are required.
     */
    void mount()
    {
        this.create();
        this.configure();
        this.mountDetached();
        this.mountToTarget();
    }

    void unmount()
    {
        cUnmount(this.target);
    }

private:
    int fd;
    int mountFD;
}

struct FileMount
{
    string source;
    string target;
    AT openFlags;
    MountAttr attributes;

    void mountDetached()
    {
        this.fd = open_tree(-1, this.source, this.openFlags | AT.RECURSIVE);
    }

    void setAttributes()
    {
        mount_setattr(this.fd, "", AT.EMPTY_PATH | AT.RECURSIVE, &this.attributes);
    }

    void mountToTarget()
    {
        move_mount(this.fd, "", 0, this.target, MOVE_MOUNT.F_EMPTY_PATH);
    }

    /**
     * mount is a convenience method to easily mount the mount point.
     * No extra function calls are required.
     */
    void mount()
    {
        this.mountDetached();
        this.setAttributes();
        this.mountToTarget();
    }

private:
    int fd;
}
