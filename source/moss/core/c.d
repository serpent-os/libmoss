/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.c
 *
 * Extra C bindings that moss requires.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.core.c;

public import core.sys.posix.sys.types : dev_t, mode_t, off_t, slong_t;
public import core.sys.posix.sys.stat : stat_t, fstat;
public import core.sys.posix.sys.utsname : uname, utsname;
public import core.sys.posix.fcntl : AT_SYMLINK_NOFOLLOW, AT_FDCWD, O_RDONLY,
    O_RDWR, O_WRONLY, O_CREAT, O_TRUNC;

public import core.stdc.stdio : SEEK_SET;
public import core.sys.posix.fcntl : mkdir, open;
public import core.sys.posix.stdlib : mkstemp, mkdtemp;
public import core.sys.posix.unistd : close, unlink, lseek, rmdir, link;
public import std.conv : octal;
public import std.string : fromStringz, toStringz;
public import core.stdc.string : strerror;
public import core.stdc.errno;

/**
 * Same as the signed long type.
 */
alias loff_t = slong_t;

/**
 * Create a directory relative to dirfd if pathname is not absolute
 */
extern (C) int mkdirat(int dirfd, scope char* pathname, mode_t mode) @system @nogc nothrow;

/**
 * Open a file relative to dirfd if pathname is not absolute
 */
extern (C) int openat(int dirfd, scope char* pathname, int flags, mode_t mode) @system @nogc nothrow;

/**
 * Unlink a file relative to dirfd if pathname is not absolute
 * Flags can either be 0 or AT_REMOVEDIR
 */
extern (C) int unlinkat(int dirfd, scope char* pathname, int flags) @system @nogc nothrow;

/**
 * Link file from relative location to relative target, if non absolute
 * paths are used.
 */
extern (C) int linkat(int olddirfd, scope char* oldpath, int newdirfd,
        scope char* newpath, int flags) @system @nogc nothrow;

/**
 * Construct a symlink from oldpath to newpath, which is relative to newdirfd
 * if newpath is not absolute.
 */
extern (C) int symlinkat(scope char* oldpath, int newdirfd, scope char* newpath) @system @nogc nothrow;

/**
 * Create special file relative to directory file descriptor
 */
extern (C) int mknodat(int dirfd, scope char* pathname, mode_t mode, dev_t dev);

/**
 * Create a FIFO special file relative to directory file descriptor.
 */
extern (C) int mkfifoat(int dirfd, scope char* pathname, mode_t mode) @system @nogc nothrow;

/**
 * Copy one part of a file to another using the defined offsets and length.
 * Allows filesystem acceleration where supported, otherwise will act much
 * the same as splice()
 */
extern (C) loff_t copy_file_range(int fd_in, loff_t* off_in, int fd_out,
        loff_t* off_out, size_t len, uint flags) @system @nogc nothrow;

version (X86_64)
{
    /**
     * Stat a file relative to dirfd if pathname is not absolute.
     * Use with AT_SYMLINK_NOFOLLOW for lstat() style behaviour.
     */
    extern (C) int fstatat64(int dirfd, scope char* pathname, scope stat_t* buf, int flags) @system @nogc nothrow;
    alias fstatat = fstatat64;
}
else
{
    /**
     * Stat a file relative to dirfd if pathname is not absolute.
     * Use with AT_SYMLINK_NOFOLLOW for lstat() style behaviour.
     */
    extern (C) int fstatat(int dirfd, scope char* pathname, scope stat_t* buf, int flags) @system @nogc nothrow;
}

/**
 * Currently druntime lacks the following symbols on Linux.
 */
version (linux)
{
    /**
     * When used with open/openat, the call will fail unless the pathname
     * is actually a directory.
     */
    enum O_DIRECTORY = 0x20000;

    /**
     * These values replicate AT_* in https://github.com/torvalds/linux/blob/master/include/uapi/linux/fcntl.h
     */
    enum AT
    {
        /**
         * NONE is not technically an existing value in the Linux kernel sources,
         * but can be used to signal the absence of an AT_* value.
         */
        NONE = 0,

        /**
        * Pass to unlinkat() for rmdir() behaviour.
        */
        REMOVEDIR = 0x200,

        /**
        * (Do) follow symlinks
        */
        SYMLINK_FOLLOW = 0x400,

        /**
        * Suppress terminal automount traversal
        */
        NO_AUTOMOUNT = 0x800,

        EMPTY_PATH = 0x1000,
        RECURSIVE = 0x8000,
    }

    /**
     * MS sets how a mount point is created or altered.
     * Multiple values can be passed by OR-ing them together, when compatible.
     * These values replicate MS_* in https://github.com/torvalds/linux/blob/v6.2/include/uapi/linux/mount.h
     */
    public enum MS : ulong
    {
        /**
         * NONE is not technically an existing value in the Linux kernel sources,
         * but can be used to signal the absence of a MS_* value.
         */
        NONE = 0,
        BIND = 4096,
        REC = 16384,
        UNBINDABLE = 1<<17,
        PRIVATE = 1<<18,
        SLAVE = 1<<19,
        SHARED = 1<<20,
    }

    /**
     * MOUNT_ATTR sets the permissions of an existing mount point.
     * Multiple values can be passed by OR-ing them together.
     * These values replicate MOUNT_ATTR_* in https://github.com/torvalds/linux/blob/v6.2/include/uapi/linux/mount.h
     */
    public enum MOUNT_ATTR : ulong
    {
        RELATIME = 0x0,
        RDONLY = 0x1,
        NOSUID = 0x2,
        NODEV = 0x4,
        NOEXEC = 0x8,
        NOATIME = 0x10,
        _ATIME = 0x70,
    }

    public struct mount_attr
    {
        MOUNT_ATTR attr_set; /* Mount attributes to set. */
        MOUNT_ATTR attr_clr; /* Mount attributes to clear. */
        MS propagation; /* Mount propagation type. */
        ulong userns_fd; /* User namespace file descriptor. */
    };

    /**
     * MNT sets the umount options.
     * Multiple values can be passed by OR-ing them together, when compatible.
     * These values replicate MNT_* in https://github.com/torvalds/linux/blob/v6.2/include/linux/fs.h
     */
    public enum MNT
    {
        /**
         * NONE is not technically an existing value in the Linux kernel sources,
         * but can be used to signal the absence of a MNT_* value.
         */
        NONE = 0,
        FORCE = 1,
        DETACH = 2,
    }

    /**
     * OPEN_TREE sets how open_tree opens a directory tree.
     * Multiple values can be passed by OR-ing them together, when compatible.
     * These values replicate OPEN_TREE_* in https://github.com/torvalds/linux/blob/v6.2/include/uapi/linux/mount.h
     */
    enum OPEN_TREE
    {
        TREE_CLONE = 1,
    }

    /**
     * Mount the filesystem specified by source to the location specified
     * by dir.
     *
     * Returns: 0 on success otherwise consult errno
     */
    extern (C) int mount(const(char*) specialFile, const(char*) dir,
                         const(char*) fstype, MS mountFlags, const void* data) @system @nogc nothrow;

    /**
     * Unmount the specialFile
     *
     * Returns: 0 on success otherwise consult errno
     */
    extern (C) int umount(const(char*) specialFile) @system @nogc nothrow;

    /**
     * Alternative call to umount specifiying some flags
     *
     * Returns: 0 on success otherwise consult errno
     */
    extern (C) int umount2(const(char*) specialFile, MNT flags) @system @nogc nothrow;

    int open_tree(int dirfd, immutable(char*) pathname, AT flags) @system @nogc nothrow
    {
        immutable int SYS_OPEN_TREE = 428;
        return cast(int) syscall(SYS_OPEN_TREE, dirfd, pathname, flags);
    }

    int mount_setattr(int dirfd, immutable(char*) pathname, AT flags, mount_attr* attr, size_t size) @system @nogc nothrow
    {
        immutable int SYS_MOUNT_SETATTR = 442;
        return cast(int) syscall(SYS_MOUNT_SETATTR, dirfd, pathname, flags, attr, size);
    }
}

extern (C) long syscall(long number, ...) @system @nogc nothrow;

@("Test mkdirat/fstatat/unlinkat")
private unittest
{
    import std.string : toStringz;
    import std.file : getcwd, chdir, isDir;
    import std.array : join;
    import std.conv : octal;
    import core.sys.posix.fcntl : S_IFMT, S_IFDIR;

    /* Move process working directory */
    auto cd = getcwd();
    auto whence = open(".", O_DIRECTORY, 0);
    chdir("..");

    assert(getcwd() != cd);

    scope (exit)
    {
        chdir(cd);
        whence.close();
    }

    /* Create 0755 directory */
    auto ret = mkdirat(whence, cast(char*) toStringz("somedir"), octal!755);
    assert(ret == 0);

    /* Ensure we made path relative to old location */
    assert(join([cd, "somedir"], "/").isDir);

    /* Relative stat */
    stat_t buf = {0};
    ret = fstatat(whence, cast(char*) toStringz("somedir"), &buf, AT_SYMLINK_NOFOLLOW);
    assert(ret == 0);
    /* Ensure we have 0755 directory now */
    assert((buf.st_mode & S_IFMT) == S_IFDIR);
    assert((buf.st_mode & ~S_IFMT) == octal!755);

    /* Remove the dir */
    ret = unlinkat(whence, cast(char*) toStringz("somedir"), AT_REMOVEDIR);
    assert(ret == 0);
}

@("Test linkat()")
private unittest
{
    import std.stdio : File;
    import std.file : mkdirRecurse, rmdir;

    /* dlang make the new paths */
    mkdirRecurse("pathA");
    mkdirRecurse("pathB");

    /* Source file creation */
    auto f = File("pathA/origin", "w");
    f.write("I AM THE DUPLICATOR\n");
    f.close();

    /* Open our dirfds */
    auto pathA = open("pathA", O_DIRECTORY, 0);
    auto pathB = open("pathB", O_DIRECTORY, 0);

    scope (exit)
    {
        close(pathA);
        close(pathB);
        rmdir("pathA");
        rmdir("pathB");
    }

    /* hardlink origin to copy */
    assert(pathA >= 0 && pathB >= 0);
    auto ret = linkat(pathA, cast(char*) toStringz("origin"), pathB,
            cast(char*) toStringz("copy"), 0);
    assert(ret == 0);

    /* Ensure it has 2 refs */
    stat_t st = {0};
    ret = fstatat(pathB, cast(char*) toStringz("copy"), &st, AT_SYMLINK_NOFOLLOW);
    assert(st.st_nlink == 2);
    assert(ret == 0);

    /* Relative deletes */
    ret = unlinkat(pathA, cast(char*) toStringz("origin"), 0);
    assert(ret == 0);
    ret = unlinkat(pathB, cast(char*) toStringz("copy"), 0);
}

@("Test copy_file_range")
private unittest
{
    import moss.core.util : computeSHA256;

    auto inputPath = "LICENSES/Zlib.txt";
    auto outputPath = "LICENSE.COPY";

    auto inpFD = open(inputPath.toStringz, O_RDONLY, 0);
    auto outFD = open(outputPath.toStringz, O_RDWR | O_CREAT, octal!644);

    assert(inpFD > 0 && outFD > 0);
    stat_t st = {0};
    assert(fstat(inpFD, &st) == 0);

    /* Wipe the file */
    scope (exit)
    {
        close(inpFD);
        close(outFD);
        unlink(outputPath.toStringz);
    }

    loff_t nBytesCopied = 0;
    loff_t length = st.st_size;

    /* Perform the in-kernel copy */
    do
    {
        nBytesCopied = copy_file_range(inpFD, null, outFD, null, length, 0);
        assert(nBytesCopied >= 0);
        length -= nBytesCopied;
    }
    while (length > 0 && nBytesCopied > 0);

    assert(computeSHA256(inputPath) == computeSHA256(outputPath));
}
