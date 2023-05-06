module moss.core.c.mounts;

import moss.core.c;
import std.exception : ErrnoException;
import std.string : toStringz;

/* fsopen family. */
version (linux)
{
    enum FSOPEN
    {
        CLOEXEC = 1,
    }

    int fsopen(const string fsname, FSOPEN flags = cast(FSOPEN) 0)
    {
        immutable int SYS_FSOPEN = 430;
        auto fd = cast(int) syscall(SYS_FSOPEN, fsname.toStringz(), flags);
        if (fd < 0)
        {
            throw new ErrnoException("Failed to open new file system");
        }
        return fd;
    }

    enum FSCONFIG
    {
        SET_FLAG,
        SET_STRING,
        SET_BINARY,
        SET_PATH,
        SET_PATH_EMPTY,
        SET_FD,
        CMD_CREATE,
        CMD_RECONFIGURE,
    }

    void fsconfig(int fd, FSCONFIG type, string key, void* value, int aux = 0)
    {
        immutable int SYS_FSCONFIG = 431;

        char* keyz = null;
        if (key != "")
        {
            keyz = cast(char*) key.toStringz();
        }
        auto ret = cast(int) syscall(SYS_FSCONFIG, fd, type, keyz, value, aux);
        if (ret < 0)
        {
            throw new ErrnoException("Failed to config file system");
        }
    }

    enum FSMOUNT
    {
        CLOEXEC = 1,
    }

    int fsmount(int fd, FSMOUNT flags = cast(FSMOUNT) 0, MS ms_flags = cast(MS) 0)
    {
        immutable int SYS_FSMOUNT = 432;
        auto newFD = cast(int) syscall(SYS_FSMOUNT, fd, flags, ms_flags);
        if (newFD < 0)
        {
            throw new ErrnoException("Failed to mount file system");
        }
        return newFD;
    }
}

/* open_tree family. */
version (linux)
{

    /**
     * These values replicate AT_* in https://github.com/torvalds/linux/blob/master/include/uapi/linux/fcntl.h
     */
    enum AT
    {
        REMOVEDIR = 0x200, /** Pass to unlinkat() for rmdir() behaviour. */
        SYMLINK_FOLLOW = 0x400, /** Do follow symlinks. */
        NO_AUTOMOUNT = 0x800, /** Suppress terminal automount traversal. */
        EMPTY_PATH = 0x1000,
        RECURSIVE = 0x8000,
    }

    enum OPEN_TREE
    {
        CLONE = 1,
        CLOEXEC = 0x80000,
    }

    AT bitOr(AT thiz, OPEN_TREE other) @safe @nogc pure
    {
        return thiz | cast(AT) other;
    }

    AT bitOr(OPEN_TREE thiz, AT other) @safe @nogc pure
    {
        return cast(AT) thiz | other;
    }

    int open_tree(int fd, const string path, AT flags)
    {
        immutable int SYS_OPEN_TREE = 428;
        auto ret = cast(int) syscall(SYS_OPEN_TREE, fd, path.toStringz(), flags);
        if (ret < 0)
        {
            throw new ErrnoException("Failed to open_tree");
        }
        return ret;
    }

    enum MOUNT_ATTR : ulong
    {
        RELATIME = 0x0,
        RDONLY = 0x1,
        NOSUID = 0x2,
        NODEV = 0x4,
        NOEXEC = 0x8,
        NOATIME = 0x10,
        STRICTATIME = 0x20,
        _ATIME = 0x70,
        NODIRATIME = 0x80,
        IDMAP = 0x100000,
        NOSYMFOLLOW = 0x200000,
    }

    struct MountAttr
    {
        MOUNT_ATTR attr_set; /** Mount attributes to set. */
        MOUNT_ATTR attr_clr; /** Mount attributes to clear. */
        MS propagation = cast(MS) 0; /** Mount propagation type. */
        ulong userns_fd; /** User namespace file descriptor. */
    }

    void mount_setattr(int fd, const string path, AT flags, MountAttr* attr)
    {
        immutable int SYS_MOUNT_SETATTR = 442;
        const auto ret = syscall(
            SYS_MOUNT_SETATTR,
            fd,
            path.toStringz(),
            flags,
            attr,
            (*attr).sizeof,
        );
        if (ret < 0)
        {
            throw new ErrnoException("Failed to set mount attributes");
        }
    }

    enum MOVE_MOUNT
    {
        F_EMPTY_PATH = 4,
    }

    void move_mount(int fromFD, const string fromPath, int toFD, const string toPath, MOVE_MOUNT flags)
    {
        immutable int SYS_MOVE_MOUNT = 429;
        const auto ret = syscall(SYS_MOVE_MOUNT, fromFD, fromPath.toStringz(), toFD, toPath.toStringz(), flags);
        if (ret < 0)
        {
            throw new ErrnoException("Failed to move mount");
        }
    }

    /* Common types and values. */
    version (linux)
    {
        /**
     * MS sets how a mount point is created or altered.
     * Multiple values can be passed by OR-ing them together, when compatible.
     * These values replicate MS_* in https://github.com/torvalds/linux/blob/v6.2/include/uapi/linux/mount.h
     */
        public enum MS : ulong
        {
            RDONLY = 1,
            NOSUID = 2,
            NODEV = 4,
            NOEXEC = 8,
            SYNCHRONOUS = 16,
            REMOUNT = 32,
            MANDLOCK = 64,
            DIRSYNC = 128,
            NOSYMFOLLOW = 256,
            NOATIME = 1024,
            NODIRATIME = 2048,
            BIND = 4096,
            MOVE = 8192,
            REC = 16384,
        }
    }

    /* umount family. */
    version (linux)
    {
        /**
     * MNT sets the umount options.
     * Multiple values can be passed by OR-ing them together, when compatible.
     * These values replicate MNT_* in https://github.com/torvalds/linux/blob/v6.2/include/linux/fs.h
     */
        enum MNT
        {
            FORCE = 1,
            DETACH = 2,
        }

        void unmount(const string path, MNT flags = cast(MNT) 0)
        {
            int ret;
            if (flags == 0)
            {
                ret = umount(path.toStringz());
            }
            else
            {
                ret = umount2(path.toStringz(), flags);
            }
            if (ret < 0)
            {
                throw new ErrnoException("Failed to unmount");
            }
        }

    private:
        extern (C) int umount(const(char*) specialFile) @system @nogc nothrow;
        extern (C) int umount2(const(char*) specialFile, MNT flags) @system @nogc nothrow;
    }
}
