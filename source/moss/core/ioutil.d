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
 * Algebraic result for most IOUtil operations
 */
public alias IOResult = SumType!(bool, CError);

/**
 * Returns a file descriptor
 */
public alias IOFDResult = SumType!(int, CError);

/**
 * Returns a temporary file result
 */
public alias IOTempResult = SumType!(TemporaryFile, CError);

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
}

@("Ensure copyFile works as expected")
private unittest
{
    auto res = IOUtil.copyFile("LICENSE", "LICENSE.test");
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
