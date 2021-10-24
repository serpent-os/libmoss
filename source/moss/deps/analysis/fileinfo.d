/*
 * This file is part of moss-deps.
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

module moss.deps.analysis.fileinfo;

import std.path;
import std.file;
import moss.core : FileType, computeSHA256;
import core.sys.posix.sys.stat;

/**
 * We use mmap when beyond 16kib
 */
static enum MmapThreshhold = 16 * 1024;

/**
 * FileInfo collects essential information about each file in a package
 * to allow further proessing.
 */
public struct FileInfo
{

    /**
     * Construct a new FileInfo from the given paths
     */
    this(const(string) relativePath, const(string) fullPath)
    {
        import std.string : toStringz, format;
        import std.exception : enforce;

        auto z = fullPath.toStringz;
        stat_t tStat = {0};
        auto ret = lstat(z, &tStat);
        enforce(ret == 0, "FileInfo: unable to stat() %s".format(fullPath));

        this(relativePath, fullPath, tStat);

    }

    /**
     * Construct a new FileInfo using the given relative path, full path,
     * and populated stat result
     */
    this(const(string) relativePath, const(string) fullPath, in stat_t statResult)
    {
        this.statResult = statResult;
        _path = relativePath;
        _fullPath = fullPath;

        /**
         * Stat the file so we can set the appropriate file type
         */
        switch (statResult.st_mode & S_IFMT)
        {
        case S_IFBLK:
            _type = FileType.BlockDevice;
            break;
        case S_IFCHR:
            _type = FileType.CharacterDevice;
            break;
        case S_IFDIR:
            _type = FileType.Directory;
            break;
        case S_IFIFO:
            _type = FileType.Fifo;
            break;
        case S_IFLNK:
            _type = FileType.Symlink;
            _data = fullPath.readLink();
            break;
        case S_IFREG:
            _type = FileType.Regular;
            break;
        case S_IFSOCK:
            _type = FileType.Socket;
            break;
        default:
            _type = FileType.Unknown;
            break;
        }
    }

    /**
     * Return the underlying file type
     */
    pure @property FileType type() const @safe @nogc nothrow
    {
        return _type;
    }

    /**
     * Return the data (symlink target or hash)
     */
    pure @property const(string) data() const @safe
    {
        import std.exception : enforce;

        enforce(type == FileType.Regular || type == FileType.Symlink,
                "FileInfo.data() only supported for symlinks + regular files");
        return _data;
    }

    /**
     * Return true if this is a relative symlink
     */
    pure @property bool relativeSymlink() const @safe
    {
        import std.string : startsWith;

        return !data.startsWith("/");
    }

    /**
     * Return the fully resolved symlink
     */
    pure @property const(string) symlinkResolved() const @safe
    {
        import std.exception : enforce;

        enforce(type == FileType.Symlink, "FileInfo.symlinkResolved() only supported for symlinks");

        auto dirn = path.dirName;
        return dirn.buildPath(data.relativePath(dirn));
    }

    /**
     * Return the target filesystem path
     */
    pure @property const(string) path() const @safe @nogc nothrow
    {
        return _path;
    }

    /**
     * Return the full path to the file on the host disk
     */
    pure @property const(string) fullPath() const @safe @nogc nothrow
    {
        return _fullPath;
    }

    /**
     * Return the target for this file
     */
    pure @property const(string) target() const @safe @nogc nothrow
    {
        return _target;
    }

    /**
     * Set the target for this analysis
     */
    pure @property void target(const(string) t) @safe @nogc nothrow
    {
        _target = t;
    }

    /**
     * Return underlying stat buffer
     */
    pure @property stat_t stat() const @safe @nogc nothrow
    {
        return statResult;
    }

    /**
     * Compute hash sum for this file
     */
    void computeHash()
    {
        /* Use mmap if the file is larger than 16kib */
        _data = computeSHA256(_fullPath, !(statResult.st_size <= MmapThreshhold));
    }

    /**
     * Return true if both depencies are equal
     */
    bool opEquals()(auto ref const FileInfo other) const
    {
        if (this.type == other.type)
        {
            if (this.type == FileType.Regular || this.type == FileType.Symlink)
            {
                return this._data == other._data;
            }
            return this.statResult == other.statResult;
        }
        else
        {
            return false;
        }
        return other.type == this.type;
    }

    /**
     * Compare two eependencies with the same type
     */
    int opCmp(ref const FileInfo other) const
    {
        if (this.type == other.type)
        {
            if (this.type == FileType.Regular || this.type == FileType.Symlink)
            {
                immutable auto dA = this._data;
                immutable auto dB = other._data;
                if (dA < dB)
                {
                    return -1;
                }
                else if (dA > dB)
                {
                    return 1;
                }
                return 0;
            }
        }
        immutable auto pA = this._data;
        immutable auto pB = this._data;
        if (pA < pB)
        {
            return -1;
        }
        else if (pA > pB)
        {
            return 1;
        }
        return 0;
    }

    /**
     * Return the hash code for the path
     */
    ulong toHash() @safe nothrow const
    {
        return typeid(string).getHash(&_path);
    }

package:

    /**
     * Return a regular file comparison struct
     */
    static FileInfo regularComparator(in string hash)
    {
        auto f = FileInfo();
        f._data = hash;
        f._type = FileType.Regular;
        return f;
    }

private:

    FileType _type = FileType.Unknown;
    string _data = null;
    string _path = null;
    string _fullPath = null;
    string _target = null;
    stat_t statResult;
}
