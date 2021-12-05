/*
 * This file is part of moss-core.
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

/**
 * Extra C bindings that moss requires
 */
module moss.core.c;

public import core.sys.posix.sys.types : mode_t, off_t, slong_t;
public import core.sys.posix.sys.stat : stat_t;
public import core.sys.posix.fcntl : AT_SYMLINK_NOFOLLOW, AT_FDCWD;

import core.sys.posix.fcntl : open;
import core.sys.posix.unistd : close;

/**
 * Same as the signed long type.
 */
alias loff_t = slong_t;

/**
 * Create a directory relative to dirfd if pathname is not absolute
 */
extern (C) int mkdirat(int dirfd, scope char* pathname, mode_t mode);

/**
 * Open a file relative to dirfd if pathname is not absolute
 */
extern (C) int openat(int dirfd, scope char* pathname, int flags, mode_t mode);

/**
 * Unlink a file relative to dirfd if pathname is not absolute
 * Flags can either be 0 or AT_REMOVEDIR
 */
extern (C) int unlinkat(int dirfd, scope char* pathname, int flags);

/**
 * Link file from relative location to relative target, if non absolute
 * paths are used.
 */
extern (C) int linkat(int olddirfd, scope char* oldpath, int newdirfd,
        scope char* newpath, int flags);

/**
 * Copy one part of a file to another using the defined offsets and length.
 * Allows filesystem acceleration where supported, otherwise will act much
 * the same as splice()
 */
extern (C) loff_t copy_file_range(int fd_in, loff_t* off_in, int fd_out,
        loff_t* off_out, size_t len, uint flags);

version (X86_64)
{
    /**
     * Stat a file relative to dirfd if pathname is not absolute.
     * Use with AT_SYMLINK_NOFOLLOW for lstat() style behaviour.
     */
    extern (C) int fstatat64(int dirfd, scope char* pathname, scope stat_t* buf, int flags);
    alias fstatat = fstatat64;
}
else
{
    /**
     * Stat a file relative to dirfd if pathname is not absolute.
     * Use with AT_SYMLINK_NOFOLLOW for lstat() style behaviour.
     */
    extern (C) int fstatat(int dirfd, scope char* pathname, scope stat_t* buf, int flags);
}

/**
 * Currently druntime lacks the following constants on Linux
 */
version (linux)
{
    /**
     * When used with open/openat, the call will fail unless the pathname
     * is actually a directory.
     */
    enum O_DIRECTORY = 0x20000;

    /**
     * Pass to unlinkat() for rmdir() behaviour.
     */
    enum AT_REMOVEDIR = 0x200;

    /**
     * Suppress terminal automount traversal
     */
    enum AT_NO_AUTOMOUNT = 0x800;

    /**
     * (Do) follow symlinks
     */
    enum AT_SYMLINK_FOLLOW = 0x400;
}

@("Test mkdirat/fstatat/unlinkat")
private unittest
{
    import std.string : toStringz;
    import std.file : getcwd, chdir, isDir;
    import std.path : buildPath;
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
    assert(cd.buildPath("somedir").isDir);

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
    import std.string : toStringz;

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
