/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.ftw
 *
 * C bindings for ftw and siblings e.g. nftw.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.core.ftw;

public import core.sys.posix.sys.stat : stat_t;

/**
 * Values for the FLAG argument to the user function passed to `ftw' and 'nftw'.
 */
enum TypeFlag
{
    // dfmt off
    FTW_F,      /* Regular file. */
    FTW_D,      /* Directory. */
    FTW_DNR,    /* Unreadable directory. */
    FTW_NS,     /* Unstatable file. */
    FTW_SL,     /* Symbolic link. */
    FTW_DP,     /* Directory, all subdirs have been visited. */
    FTW_SLN,    /* Symbolic link naming non-existing file. */
    // dfmt on
}

/**
 * Flags for fourth argument of `nftw'.
 */
enum NftwFlags
{
    // dfmt off
    FTW_PHYS = 1,           /* Perform physical walk, ignore symlinks. */
    FTW_MOUNT = 2,          /* Report only files on same file system as the argument. */
    FTW_CHDIR = 4,          /* Change to current directory while processing it. */
    FTW_DEPTH = 8,          /* Report files in directory before directory itself. */
    FTW_ACTIONRETVAL = 16,  /* (GNU) Assume callback to return FTW_* values instead of zero to continue and non-zero to terminate. */
    // dfmt on
}

/**
 * (GNU) Return values from callback functions.
 */
enum RetVal
{
    // dfmt off
    FTW_CONTINUE = 0,       /* Continue with next sibling or for FTW_D with the first child. */
    FTW_STOP = 1,           /* Return from `ftw' or `nftw' with FTW_STOP as return value. */
    FTW_SKIP_SUBTREE = 2,   /* Only meaningful for FTW_D: Don't walk through the subtree, instead just continue with its next sibling. */
    FTW_SKIP_SIBLINGS = 3,  /* Continue with FTW_DP callback for current directory (if FTW_DEPTH) and then its siblings. */
    // dfmt on
}

/**
 * Structure used for fourth argument to callback function for `nftw'.
 */
struct FTW
{
    /**
     * start directory?
     */
    int base;
    /**
     * n of dirs deep from base?
     */
    int level;
}

version (X86_64)
{
    /**
     * Call a function on every element in a directory tree.
     * This function is a possible cancellation point and therefore not
     * marked with __THROW.
     */
    // dfmt off
    extern (C) int ftw64(const char *dirpath,
                    int function (const char *fpath, const stat_t *sb, int typeflag)
                    fn, int nopenfd);
    // dfmt on
    alias ftw = ftw64;
}
else
{
    /**
     * Call a function on every element in a directory tree.
     * This function is a possible cancellation point and therefore not
     * marked with __THROW.
     */
    // dfmt off
    extern (C) int ftw(const char *dirpath,
                    int function (const char *fpath, const stat_t *sb, int typeflag)
                    fn, int nopenfd);
    // dfmt on
}

version (X86_64)
{
    /**
     * Call a function on every element in a directory tree.  FLAG allows
     * to specify the behaviour more detailed.
     * This function is a possible cancellation point and therefore not
     * marked with __THROW.
     */
    // dfmt off
    extern (C) int nftw64(const char *dirpath,
                        int function (const char *fpath, const stat_t *sb, int typeflag, FTW *ftwbuf)
                        fn, int nopenfd, int flags);
    // dfmt on
    alias nftw = nftw64;
}
else
{
    /**
     * Call a function on every element in a directory tree.  FLAG allows
     * to specify the behaviour more detailed.
     * This function is a possible cancellation point and therefore not
     * marked with __THROW.
     */
    // dfmt off
    extern (C) int nftw(const char *dirpath,
                        int function (const char *fpath, const stat_t64 *sb, int typeflag, FTW *ftwbuf)
                        fn, int nopenfd, int flags);
    // dfmt on
}

@("Testing ftw()") @system private unittest
{
    import std.file : getSize, mkdir, rmdirRecurse;
    import std.stdio : File;
    import std.string : format, toStringz;

    auto path = "ftw-testing-path";
    mkdir(path);

    /* Create a file for testing */
    auto f = File(path ~ "/foo", "w");
    f.write("I HAZ BYTES\n");
    f.close();

    immutable fileBytes = getSize(path ~ "/foo");

    /* Anything interacting with the handler needs to be static */
    static ulong totalSize;

    /* Get size of files in path */
    extern (C) int handler(const char* fpath, const stat_t* sb, int typeflag)
    {
        switch (typeflag)
        {
        case TypeFlag.FTW_F:
            totalSize += sb.st_size;
            break;
        default:
            break;
        }
        return 0;
    }

    /* No. of open file descriptors, if it's exceeded it'll be slower */
    enum nopenfd = 16;
    /* Walk the path */
    const ret = ftw(path.toStringz, &handler, nopenfd);

    scope (exit)
    {
        rmdirRecurse(path);
    }

    assert(ret == 0);
    assert(totalSize == fileBytes);

    totalSize = 0;
}

@("Testing nftw()") @system private unittest
{
    import std.file : mkdirRecurse, rmdirRecurse, symlink, write;
    import std.string : toStringz;
    import std.path : buildPath;

    immutable path = "nftw-testing";

    /* Make dirs to iterate over */
    auto makedirs = buildPath(path, "foo", "bar");
    mkdirRecurse(makedirs);

    /* Make symlink for testing */
    auto source = makedirs ~ "source";
    auto target = makedirs ~ "target";
    target.write("target");
    target.symlink(source);

    static ulong dirs;
    static ulong syms;

    extern (C) int nftwhandler(const char* fpath, const stat_t* sb, int typeflag, FTW* ftwbuf)
    {
        switch (typeflag)
        {
        case TypeFlag.FTW_DP:
            dirs++;
            break;
        case TypeFlag.FTW_SL:
            syms++;
            break;
        default:
            break;
        }
        /* Normally just return 0 here, but we want to test RetVal is working */
        return RetVal.FTW_CONTINUE;
    }

    /* No. of open file descriptors, if it's exceeded it'll be slower */
    enum nopenfd = 32;
    /* Ensure custom flags are working */
    int flags = NftwFlags.FTW_DEPTH | NftwFlags.FTW_PHYS | NftwFlags.FTW_ACTIONRETVAL;
    /* Walk the path */
    const ret = nftw(path.toStringz, &nftwhandler, nopenfd, flags);

    scope (exit)
    {
        rmdirRecurse(path);
    }

    assert(ret == RetVal.FTW_CONTINUE);
    assert(dirs == 3);
    assert(syms == 1);

    dirs = 0;
    syms = 0;
}
