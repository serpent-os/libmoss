/* SPDX-License-Identifier: Zlib */

/**
 * moss.core.download.manager
 *
 * Defines how to finagle downloads into a moss store.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.core.download.manager;

public import moss.core.download.store;

/**
 * A Download is an as-yet-unimplemented type that will
 * be used for download tracking
 */
struct Download
{
    /** Where to find the file */
    string uri;

    /** Expected hash when downloaded */
    string expectedHash;
}

/**
 * A DownloadManager is responsible for downloading files from the network
 * to disk, and storing them in a DownloadStore. Once verified, files are
 * permitted for use.
 *
 * Additionally a DownloadManager may make use of multiple caches in order
 * to permit cache sharing, i.e. bind-mounted host downloads into a guest
 * instance of moss.
 */
final class DownloadManager
{

public:

    /**
     * Add a cache to our list of known caches
     *
     * System caches are always checked first
     */
    void add(DownloadStore c) @safe
    {
        import std.algorithm.sorting : sort;

        stores ~= c;

        /* Sort: System first */
        sort!((a, b) => a.type > b.type)(stores);
    }

    /**
     * Add a download to the queue
     */
    void add(Download d) @safe
    {
        import std.string : toLower;

        d.expectedHash.toLower();
        toDownload ~= d;
    }

    /**
     * Return true if we have the file in our caches
     */
    bool contains(const(string) hash) @safe nothrow
    {
        foreach (ref st; stores)
        {
            if (st.contains(hash))
            {
                return true;
            }
        }
        return false;
    }

    /**
     * Fetch all files in the queue, verifying + staging as we go
     */
    void fetch() @system
    {
        import std.algorithm : filter;
        import std.array : array;
        import std.exception : enforce;
        import std.file : mkdirRecurse;
        import std.path : dirName;

        auto writable = stores.filter!((a) => a.writable).array;
        enforce(writable.length >= 1, "DownloadManager.fetch(): No writable stores found");
        auto writeStore = writable[0];

        import std.stdio : writefln, writeln;

        writefln("Using cache: %s", writeStore.directory);

        /* Ugly download code */
        foreach (ref d; toDownload)
        {
            import std.net.curl : download;
            import std.string : format;

            /* Download the staging file */
            auto fullPath = writeStore.stagingPath(d.expectedHash);
            auto downloadDir = fullPath.dirName;
            downloadDir.mkdirRecurse();
            writeln(fullPath);
            download(d.uri, fullPath);

            /* Verify the hash */
            auto hash = checkHash(fullPath);
            if (hash != d.expectedHash)
            {
                import std.file : remove;

                remove(fullPath);
                writeln(hash, " vs ", d.expectedHash);
            }
            assert(hash == d.expectedHash,
                    "DownloadManager.fetch(): Corrupt download %s".format(d.uri));

            /* IF VERIFIED.. */
            writeStore.promote(d.expectedHash);
        }
    }

    /**
     * Find responsible download store, share contents to target location
     */
    void share(const(string) hash, const(string) target) @system
    {
        import std.algorithm : filter;
        import std.array : array;
        import std.exception : enforce;
        import std.file : mkdirRecurse;
        import std.string : format;
        import std.path : dirName;

        /* Ensure storage destination exists */
        auto dirn = dirName(target);
        dirn.mkdirRecurse();

        /* find home */
        auto storageHomes = stores.filter!((a) => a.contains(hash)).array;
        enforce(storageHomes.length >= 1,
                "DownloadManager.share(): No store found for %s".format(hash));
        auto storageHome = storageHomes[0];

        storageHome.share(hash, target);
    }

private:

    /**
     * Ugly utility to check a hash, we should build this while downloading
     * the file.
     */
    string checkHash(const(string) path)
    {
        import std.stdio : File;
        import std.digest.sha : SHA256Digest, toHexString;
        import std.string : toLower;

        auto sha = new SHA256Digest();
        auto input = File(path, "rb");
        foreach (ubyte[] buffer; input.byChunk(16 * 1024 * 1024))
        {
            sha.put(buffer);
        }
        return toHexString(sha.finish()).toLower();
    }

    DownloadStore[] stores;
    Download[] toDownload;
}
