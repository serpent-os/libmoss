/* SPDX-License-Identifier: Zlib */

/**
 * Store
 *
 * Defines a DownloadStore for downloading + fetching files into
 * the moss store.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: ZLib
 */
module moss.core.download.store;

public import moss.core.store;

/**
 * The DownloadStore is a specialist implementation of the DiskStore
 * used for downloading + fetching files.
 */
final class DownloadStore : DiskStore
{

    @disable this();

    /**
     * Construct a new DownloadStore with the given StoreType.
     * The DownloadStore will then initialise the supertype
     * constructor to use the relevant storage locations on disk.
     */
    this(StoreType type)
    {
        super(type, "downloads", "v1");
    }

    /**
     * Specialised handler for full paths
     */
    override string fullPath(const(string) name)
    {
        import std.array : join;

        if (name.length > 10)
        {
            return join([directory, name[0 .. 5], name[$ - 5 .. $], name], "/");
        }
        return super.fullPath(name);
    }
}
