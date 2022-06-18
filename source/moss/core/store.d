/* SPDX-License-Identifier: Zlib */

/**
 * moss.core.store
 *
 * Defines and implements various moss user and system on-disk stores.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.core.store;

/**
 * Type of cache being employed, affects writability
 */
final enum StoreType
{
    /* User specific cache */
    User = 0,

    /* System wide cache */
    System,
}

/**
 * The DiskStore is the most basic storage cache within Moss. It is initialised
 * as either a system or user cache, and has a fixed root directory from which
 * to work.
 */
abstract class DiskStore
{

public:

    /**
     * Return the cache type
     */
    pure final @property StoreType type() @safe @nogc nothrow
    {
        return _type;
    }

    /**
     * Return the name identifier
     */
    pure final @property const(string) identifier() @safe @nogc nothrow
    {
        return _identifier;
    }

    /**
     * Return the version identifier
     */
    pure final @property const(string) versionIdentifier() @safe @nogc nothrow
    {
        return _versionIdentifier;
    }

    /**
     * Returns true if this cache is writable by the current user
     */
    pure final @property bool writable() @safe @nogc nothrow
    {
        return _writable;
    }

    /**
     * Return the root directory for this cache
     */
    pure final @property const(string) directory() @safe @nogc nothrow
    {
        return _directory;
    }

    /**
     * Return true if we contain the given name in our cache
     */
    final bool contains(const(string) name) @safe nothrow
    {
        import std.file : exists;

        try
        {
            return fullPath(name).exists;
        }
        catch (Exception ex)
        {
            return false;
        }
    }

    /**
     * Take a file out of staging, atomically shift it into the promoted
     * tree
     */
    final void promote(const(string) name) @safe
    {
        import std.file : mkdirRecurse, rename;
        import std.path : dirName;

        auto sourcePath = stagingPath(name);
        auto targetPath = fullPath(name);

        auto dirs = dirName(targetPath);
        dirs.mkdirRecurse();
        sourcePath.rename(targetPath);
    }

    /**
     * Share our resource with another consumer, via a link if possible
     */
    final void share(const(string) id, const(string) target) @system
    {
        import moss.core.util : hardLink;

        hardLink(fullPath(id), target);
    }

    /**
     * May be overridden by specific implementations to give a more
     * specific string splitting function.
     */
    string fullPath(const(string) name) @safe
    {
        import std.array : join;

        return join([_directory, name], "/");
    }

    /**
     * Return staging path name for in-transit assets
     */
    string stagingPath(const(string) name) @safe
    {
        import std.array : join;

        return join([_directory, "staging", name], "/");
    }

package:

    @disable this();

    /**
     * Construct a new DiskStore with the given identifier
     */
    this(StoreType type, string id, string versionID)
    {
        import std.path : expandTilde;
        import std.file : mkdirRecurse;
        import std.array : join;

        _type = type;
        _identifier = id;
        _versionIdentifier = versionID;

        /* Build the correct root */
        auto userHome = expandTilde("~");
        final switch (type)
        {
        case StoreType.System:
            _directory = join(["/.moss/store", identifier,
                    versionIdentifier], "/");
            break;
        case StoreType.User:
            _directory = join([
                userHome, ".moss/store", identifier, versionIdentifier
            ], "/");
            break;
        }

        /* Blindly attempt construction, ignoring errors */
        try
        {
            _directory.mkdirRecurse();
        }
        catch (Exception ex)
        {
        }

        /* Check if the directory exists + is writable */
        import moss.core.util : checkWritable;

        writable = checkWritable(_directory);
    }

    /**
     * Set the cache type
     */
    pure final @property void type(StoreType t) @safe @nogc nothrow
    {
        _type = type;
    }

    /**
     * Set the name identifier
     */
    pure final @property void identifier(const(string) id) @safe @nogc nothrow
    {
        _identifier = identifier;
    }

    /**
     * Set the version identifier
     */
    pure final @property void versionIdentifier(const(string) id) @safe @nogc nothrow
    {
        _versionIdentifier = id;
    }

    /**
     * Set writability
     */
    pure final @property void writable(bool w) @safe @nogc nothrow
    {
        _writable = w;
    }

    /**
     * Set the associated root directory
     */
    pure final @property void directory(string d) @safe @nogc nothrow
    {
        _directory = d;
    }

private:

    string _identifier;
    string _versionIdentifier;
    bool _writable = false;
    StoreType _type = StoreType.User;
    string _directory = null;
}
