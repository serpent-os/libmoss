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

import moss.core : KernelChunkSize;
import moss.core.c;
import std.sumtype;
import core.stdc.errno;
import core.stdc.string : strerror;

/**
 * Encapsulates errors from C functions
 */
public struct CError
{
    int errorCode = 0;

    /**
     * Return the display string for the error
     */
    @property const(char[]) toString() const
    {
        return fromStringz(strerror(errorCode));
    }
}

alias IOResult = SumType!(bool, CError);

/**
 * Forcibly namespace all of the operations to ensure no conflicts with the stdlib.
 */
public struct IOUtil
{
    /**
     * Copy the file fromPath into new file toPath, with optional mode (octal)
     */
    static IOResult copyFile(in string fromPath, in string toPath, mode_t mode = octal!644)
    {
        auto fdin = open(fromPath.toStringz, O_RDONLY | O_CLOEXEC, 0);
        auto fdout = open(toPath.toStringz, O_WRONLY | O_CREAT | O_TRUNC, mode);

        scope (exit)
        {
            close(fdin);
            close(fdout);
        }

        return copyFile(fdin, fdout);
    }

    /**
     * Directly copy from the input file descriptor to the output file descriptor
     */
    static IOResult copyFile(int fdIn, int fdOut)
    {
        loff_t nBytes = 0;
        do
        {
            nBytes = copy_file_range(fdIn, null, fdOut, null, KernelChunkSize, 0);
            if (nBytes < 0)
            {
                return IOResult(CError(errno));
            }
        }
        while (nBytes > 0);

        return IOResult(true);
    }
}

private unittest
{
    auto res = IOUtil.copyFile("LICENSE", "LICENSE.test");
    scope (exit)
    {
        unlink("LICENSE.test".toStringz);
    }
    res.match!((err) => assert(0, err.toString), (ok) {});
}
