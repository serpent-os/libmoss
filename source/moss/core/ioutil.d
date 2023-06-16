/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.ioutil
 *
 * Extra I/O related C bindings that moss requires.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.core.ioutil;

import cstdlib = moss.core.c;
import std.sumtype;
public import std.conv : octal;
public import std.string : fromStringz, toStringz;

/**
 * Encapsulates errors from C functions
 */
public struct CError
{
    /**
     * Set from errno();
     */
    int errorCode = 0;

    /**
     * Return the display string for the error
     */
    @property const(char[]) toString() const
    {
        return fromStringz(cstdlib.strerror(errorCode));
    }
}

/**
 * A successful temporary file has an open file descriptor and a path
 */
public struct TemporaryFile
{
    /**
     * File descriptor, already open
     */
    int fd = -1;

    /**
     * Real path (for reading, etc.)
     */
    string realPath = null;
}

/**
 * A directory walk result will return whether it was successful, the
 * size, and, the number of files and directories walked.
 */
public struct DirectoryWalkResult
{
    /**
     * Succesfully walked the directory?
     */
    bool success = false;
    /**
     * Total disk size of the directory
     */
    ulong totalSize = -1;
    /**
     * Number of files walked
     */
    ulong files = -1;
    /**
     * Number of directories walked
     */
    ulong directories = -1;
}

/**
 * Algebraic result for most IOUtil operations
 */
public alias IOResult = SumType!(bool, CError);

/**
 * Returns a file descriptor
 */
public alias IOFDResult = SumType!(int, CError);

/**
 * Returns the walk result
 */
public alias IOWalkResult = SumType!(DirectoryWalkResult, CError);

/**
 * Returns a temporary file result
 */
public alias IOTempResult = SumType!(TemporaryFile, CError);

/**
 * Return a temporary directory result
 */
public alias IOTempdResult = SumType!(string, CError);

/**
 * Forcibly namespace all of the operations to ensure no conflicts with the stdlib.
 */
public struct IOUtil
{
    /**
     * Copy the file fromPath into new file toPath, with optional mode (octal)
     */
    static IOResult copyFile(in string fromPath, in string toPath, cstdlib.mode_t mode = octal!644)
    {
        scope (exit)
        {
            cstdlib.errno = 0;
        }

        auto fdin = cstdlib.open(fromPath.toStringz, cstdlib.O_RDONLY, 0);
        if (fdin <= 0)
        {
            return IOResult(CError(cstdlib.errno));
        }
        auto fdout = cstdlib.open(toPath.toStringz,
                cstdlib.O_WRONLY | cstdlib.O_CREAT | cstdlib.O_TRUNC, mode);
        if (fdout <= 0)
        {
            return IOResult(CError(cstdlib.errno));
        }

        scope (exit)
        {
            cstdlib.close(fdin);
            cstdlib.close(fdout);
        }

        return copyFile(fdin, fdout);
    }

    /**
     * Directly copy from the input file descriptor to the output file descriptor
     * If the length isn't provided, it will be discovered using fstat()
     */
    static IOResult copyFile(int fdIn, int fdOut, long len = 0)
    {
        scope (exit)
        {
            cstdlib.errno = 0;
        }

        /* Acquire the length using fstat() */
        if (len < 1)
        {
            cstdlib.stat_t st = {0};
            auto ret = cstdlib.fstat(fdIn, &st);
            if (ret < 0)
            {
                return IOResult(CError(cstdlib.errno));
            }
            len = st.st_size;
        }

        return copyFileRange(fdIn, 0, fdOut, 0, len);
    }

    /**
     * Copy only a part of fdIn to fdOut
     */
    static IOResult copyFileRange(int fdIn, long inOffsets, int fdOut, long outOffsets, long len)
    {
        scope (exit)
        {
            cstdlib.errno = 0;
        }

        cstdlib.loff_t inOff = inOffsets;
        cstdlib.loff_t outOff = outOffsets;
        cstdlib.loff_t nBytes = 0;

        do
        {
            nBytes = cstdlib.copy_file_range(fdIn, &inOff, fdOut, &outOff, len, 0);
            if (nBytes < 0)
            {
                return IOResult(CError(cstdlib.errno));
            }
            len -= nBytes;
        }
        while (len > 0 && nBytes);

        return IOResult(true);
    }

    /**
     * Sane mkdir wrapper that allows defining the creation mode.
     */
    static IOResult mkdir(in string path, cstdlib.mode_t mode = octal!755, bool ignoreExists = false)
    {
        scope (exit)
        {
            cstdlib.errno = 0;
        }

        auto ret = cstdlib.mkdir(path.toStringz, mode);
        if (ret == 0)
        {
            return IOResult(true);
        }
        auto err = cstdlib.errno;
        if (ignoreExists && err == cstdlib.EEXIST)
        {
            return IOResult(true);
        }
        return IOResult(CError(err));
    }

    /**
     * Create a new write only file
     */
    static IOFDResult create(in string path, cstdlib.mode_t mode = octal!644)
    {
        scope (exit)
        {
            cstdlib.errno = 0;
        }

        auto ret = cstdlib.open(path.toStringz,
                cstdlib.O_WRONLY | cstdlib.O_CREAT | cstdlib.O_TRUNC, mode);
        if (ret < 0)
        {
            return IOFDResult(CError(cstdlib.errno));
        }
        return IOFDResult(ret);
    }

    /**
     * Create a new temporary file. Upon success we will return the resolved filename
     * and the open file descriptor. This can be associated with `File.fdopen` call.
     * The user should ensure they respect the tmpfs mount point (i.e. `/tmp`) and
     * consult `mkstemp()` documentation for XXXXXX usage.
     */
    static IOTempResult createTemporary(in string pattern)
    {
        scope (exit)
        {
            cstdlib.errno = 0;
        }

        /* Dup into NUL terminated buffer to get the real path back */
        auto copyBuffer = new char[pattern.length + 1];
        copyBuffer[0 .. pattern.length] = pattern;
        copyBuffer[pattern.length] = '\0';

        /* Try to open the tmpfile now */
        auto ret = cstdlib.mkstemp(copyBuffer.ptr);
        if (ret < 0)
        {
            return IOTempResult(CError(cstdlib.errno));
        }

        /* Return open file descriptor + the resolved name */
        return IOTempResult(TemporaryFile(ret, cast(string) copyBuffer.fromStringz));
    }

    /**
     * Create a temporary directory using the system /tmp directory.
     * Consult mkstemp() for XXXXXX usage
     */
    static IOTempdResult createTemporaryDirectory(in string pattern)
    {
        scope (exit)
        {
            cstdlib.errno = 0;
        }
        auto copyBuffer = new char[pattern.length + 1];
        copyBuffer[0 .. pattern.length] = pattern;
        copyBuffer[pattern.length] = '\0';
        char* retPtr = null;

        retPtr = cstdlib.mkdtemp(copyBuffer.ptr);
        if (retPtr is null)
        {
            return IOTempdResult(CError(cstdlib.errno));
        }

        return IOTempdResult(cast(string) copyBuffer.fromStringz);
    }

    /**
     * Deletes all files in a directory. A lot faster than rmdirRecurse.
     * Params:
     *   path = directory to remove
     *   keepRootDir = delete everything in the directory but not the directory itself (default: false)
     * Returns: sumtype (DirectoryWalkResult | CError)
     */
    static IOWalkResult deleteDir(in string path, bool keepRootDir = false) @trusted
    {
        import moss.core.ftw : FTW, nftw, NftwFlags, stat_t, TypeFlag;
        import std.file : FileException, exists, remove, rmdir;
        import std.parallelism : parallel;
        import std.string : fromStringz, toStringz;

        scope (exit)
        {
            cstdlib.errno = 0;
        }

        if (!path.exists)
        {
            return IOWalkResult(CError(cstdlib.errno));
        }

        /* Static vars to interact with the handler */
        static string[] dirs;
        dirs.length = 0;
        dirs.assumeSafeAppend();
        static string[] files;
        files.length = 0;
        files.assumeSafeAppend();
        static ulong size;
        size = 0;

        /* nftw handler */
        extern (C) static int handler(const char* fpath, const stat_t* sb,
                int typeflag, FTW* ftwbuf)
        {
            const path = fpath.fromStringz.idup;
            switch (typeflag)
            {
            case TypeFlag.FTW_F:
            case TypeFlag.FTW_SL:
            case TypeFlag.FTW_SLN:
                files ~= path;
                size += sb.st_size;
                break;

                /* Skip FTW_D to ensure dirs are sorted depth first */
            case TypeFlag.FTW_DP:
                dirs ~= path;
                break;

            default:
                break;
            }
            return 0;
        }
        /* No. of open fds */
        enum nopenfd = 4096;
        /* Depth first, same mount only, don't follow symlinks */
        int flags = NftwFlags.FTW_DEPTH | NftwFlags.FTW_MOUNT | NftwFlags.FTW_PHYS;
        /* Walk the path */
        const ret = nftw(path.toStringz, &handler, nopenfd, flags);

        if (ret != 0)
        {
            return IOWalkResult(CError(ret));
        }

        if (keepRootDir == true)
        {
            dirs = dirs[0 .. $ - 1];
        }

        bool success = true;
        try
        {
            /* Delete files in parallel */
            foreach (file; parallel(files))
            {
                remove(file);
            }
            /* Remove dirs, they're sorted depth first */
            foreach (dir; dirs)
            {
                remove(dir);
            }
        }
        catch (FileException e)
        {
            /* Try and keep going */
            success = false;
        }

        /* Assign to a TLS vars for return */
        immutable ulong deletedSize = size;
        immutable ulong retFiles = files.length;
        immutable ulong retDirs = dirs.length;

        return IOWalkResult(DirectoryWalkResult(success, deletedSize, retFiles, retDirs));
    }

    /**
     * Create a hardlink between two paths
     *
     * Params:
     *      source = Path to hardlink *from*
     *      target = Path to hardlink *to*
     * Returns: sumtype (bool true | CError)
     */
    static IOResult hardlink(in string source, in string target) @trusted
    {
        auto ret = cstdlib.link(source.toStringz, target.toStringz);

        if (ret == 0)
        {
            return IOResult(true);
        }

        return IOResult(CError(cstdlib.errno));
    }

    /**
     * Hardlink the files. If this fails, try to copy.
     *
     * Params:
     *      source = Path to hardlink *from*
     *      target = Path to hardlink *to*
     * Returns: sumtype (bool true | CError)
     */
    static IOResult hardlinkOrCopy(in string source, in string target) @trusted
    {
        import std.format : format;
        import std.stdio : stderr, writeln;

        auto ret = IOUtil.hardlink(source, target);
        auto err = ret.match!((e) => e.errorCode, (b) => 0);
        switch (err)
        {
        case cstdlib.EXDEV:
            import std.file : copy, FileException;

            debug
            {
                stderr.writeln(format!"%s: [EXDEV] Hardlinking %s to %s failed, trying to copy instead..."(
                        __FUNCTION__, source, target));
            }
            /* neither hardlink nor copy_file_range supports cross-mountpoint
               linking/copying so use a dumb(er) copy */
            IOResult copyRes;
            try
            {
                copyRes = IOResult(true);
                source.copy(target);
            }
            catch (FileException e)
            {
                /* Be as helpful as possible wrt troubleshooting the problem */
                stderr.writeln(format!"Copying %s to %s failed: %s"(source, target, e.msg));
                copyRes = IOResult(CError(e.errno));
            }
            return copyRes;
        case cstdlib.EMLINK:
        case cstdlib.EPERM:
            debug
            {
                /* Be as helpful as possible wrt troubleshooting the problem */
                string errType = err != cstdlib.EMLINK ? "[EPERM]" : "[ELINK]";
                stderr.writeln(format!"%s: %s Hardlinking %s to %s failed, trying to copy instead..."(__FUNCTION__,
                        errType, source, target));
            }
            return IOUtil.copyFile(source, target);
        case 0:
            return IOResult(true);
        default:
            return IOResult(CError(err));
        }
    }
}

@("Ensure copyFile works as expected")
private unittest
{
    auto res = IOUtil.copyFile("LICENSES/Zlib.txt", "LICENSE.test");
    scope (exit)
    {
        cstdlib.unlink("LICENSE.test".toStringz);
    }
    res.match!((err) => assert(0, err.toString), (ok) {});
}

@("Ensure tmpfile wrappage works as expected")
private unittest
{
    import std.stdio : File;
    import std.file : read;

    auto res = IOUtil.createTemporary("/tmp/somefileXXXXXX");
    TemporaryFile tmp = res.match!((err) => assert(0, err.toString), (t) => t);
    scope (exit)
    {
        cstdlib.unlink(tmp.realPath.toStringz);
    }

    const auto theWrittenWord = "This is a temporary file, we're reading + writing it";
    File fi;
    fi.fdopen(tmp.fd, "wb");
    fi.write(theWrittenWord);
    fi.close();

    auto contents = cast(string) read(tmp.realPath);
    assert(contents == theWrittenWord);
}

@("Ensure mkdtemp wrapper works too")
private unittest
{
    import std.file : exists, isDir;
    import std.stdio : writefln, stdout;

    auto result = IOUtil.createTemporaryDirectory("/tmp/ioutil.XXXXXX");
    string name = result.tryMatch!((string name) => name);
    scope (exit)
    {
        cstdlib.rmdir(name.toStringz);
    }
    stdout.writefln!"mkdtemp: %s"(name);
    assert(name.exists);
    assert(name.isDir);
}
