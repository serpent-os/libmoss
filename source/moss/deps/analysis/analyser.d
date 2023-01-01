/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.analysis.analyser
 *
 * Defines how moss processes and analyses files for inclusion/exclusion
 * in moss .stone packages.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.analysis.analyser;

public import moss.deps.analysis.bucket;
public import moss.deps.analysis.chain;

import std.container.rbtree;
import std.exception : enforce;
import std.parallelism : parallel, taskPool, totalCPUs;
import std.range : empty;
import std.string : format;
import std.typecons : Nullable;
import xxhash : XXH3_128;

/**
 * We may set custom attributes per file. These are stored in a mapping
 * internally with the store keyed by name
 */
package struct AttributeStore(T)
{
    /* filepath -> value */
    T[string] attributes;
}

/**
 * The Analyser is used to query sets of files for inclusion status as well
 * as permit post processing on files as and when they're encountered. As
 * such we can support dependency collection, etc.
 */
public final class Analyser
{

    alias ChainTree = RedBlackTree!(AnalysisChain, "a.priority > b.priority", true);

    /**
     * Construct a new Analyser with presorted chain trees
     */
    this()
    {
        chains = new ChainTree();

        /* Set up hash helpers */
        numCPUs = totalCPUs();
        foreach (i; 0 .. numCPUs)
        {
            hashHelpers ~= new XXH3_128();
        }
    }

    /**
     * Return the userdata as an accessible property
     */
    pragma(inline, true) pure @property T userdata(T)()
    {
        auto ret = cast(T) _userdata;
        enforce(ret !is null, "Analyser.userdata(): cast to " ~ T.stringof ~ " failed");
        return ret;
    }

    /**
     * Set the userdata
     */
    pure @property void userdata(T)(T v) @nogc nothrow
    {
        _userdata = cast(void*) v;
    }

    /**
     * Add a processing chain
     */
    void addChain(AnalysisChain chain)
    {
        chains.insert(chain);
    }

    /**
     * Add a single file for processing
     */
    void addFile(ref FileInfo file)
    {
        enforce(file.target != "" && file.target !is null, "FileInfo has no target");

        synchronized (this)
        {
            pendingFiles ~= file;

            /* Ensure bucket exists! */
            if (file.target in _buckets)
            {
                return;
            }
            _buckets[file.target] = new AnalysisBucket(file.target);
        }
    }

    /**
     * Forcibly include a file, bypassing chains + safety!
     */
    void forceAddFile(ref FileInfo file)
    {
        enforce(file.target != "" && file.target !is null, "FileInfo has no target");
        synchronized (this)
        {
            if (!(file.target in _buckets))
            {
                _buckets[file.target] = new AnalysisBucket(file.target);
            }

            auto bucket = _buckets[file.target];
            auto localHelper = hashHelpers[taskPool.workerIndex];
            localHelper.reset();
            bucket.add(file, localHelper);
        }
    }

    /**
     * Return bucket for the given FileInfo
     */
    pure @property AnalysisBucket bucket(in FileInfo info)
    {
        return bucket(info.target);
    }

    /**
     * Return a bucket by name
     */
    pure @property AnalysisBucket bucket(in string name)
    {
        return _buckets[name];
    }

    /**
     * Return all known buckets
     */
    pure @property auto buckets()
    {
        return _buckets.values();
    }

    /**
     * Return true if we have a bucket with the given name
     */
    pure bool hasBucket(in string name)
    {
        return (name in _buckets) !is null;
    }

    /**
     * Very simple method to process all incoming files 
     */
    void process()
    {
        import std.algorithm : remove;

        currentFiles = pendingFiles;
        while (currentFiles.length > 0)
        {
            pendingFiles = [];

            foreach (fi; currentFiles.parallel())
            {
                immutable auto fileAction = processOne(fi);
                auto localHelper = hashHelpers[taskPool.workerIndex];
                localHelper.reset();

                final switch (fileAction)
                {
                case Action.IncludeFile:
                    _buckets[fi.target].add(fi, localHelper);
                    break;
                case Action.IgnoreFile:
                    break;
                case Action.Unhandled:
                    throw new Exception("Unhandled file: %s".format(fi.fullPath));
                }
            }

            currentFiles = pendingFiles;
        }
    }

private:

    static enum Action
    {
        IncludeFile,
        IgnoreFile,
        Unhandled
    }

    /**
     * Process just one file.
     *
     * We'll execute all functions from all chains with a deterministic order
     * all the time we get a NextHandler or NextFunction call. Our goal is to
     * traverse the chains to get an Include or Ignore result from a whole
     * chain to allow full processing.
     */
    immutable(Action) processOne(ref FileInfo fi)
    {
        auto fileAction = Action.Unhandled;

        primary_loop: foreach (chain; chains)
        {
            enforce(chain.funcs !is null && chain.funcs.length > 0, "Non functioning handler");

            auto funcIndex = 0;
            AnalysisFunc func = null;
            long chainLength = cast(long) chain.funcs.length;
            immutable auto cmp = chainLength - 1;

            secondary_loop: while (true)
            {
                func = chain.funcs[funcIndex];
                immutable auto ret = func(this, fi);
                final switch (ret)
                {
                case AnalysisReturn.NextFunction:
                    ++funcIndex;
                    enforce(funcIndex <= cmp);
                    continue secondary_loop;
                case AnalysisReturn.NextHandler:
                    continue primary_loop;
                case AnalysisReturn.IncludeFile:
                    fileAction = Action.IncludeFile;
                    break primary_loop;
                case AnalysisReturn.IgnoreFile:
                    fileAction = Action.IgnoreFile;
                    break primary_loop;
                }
            }
        }

        return fileAction;
    }

    ChainTree chains;
    AnalysisBucket[string] _buckets;
    FileInfo[] pendingFiles;
    FileInfo[] currentFiles;
    uint numCPUs = 0;
    XXH3_128[] hashHelpers;
    void* _userdata = null;
}

unittest
{
    static AnalysisReturn acceptLicense(scope Analyser analyser, ref FileInfo fi)
    {
        if (fi.path == "LICENSE")
        {
            auto f = FileInfo("README.md", "README.md");
            f.target = "main";
            analyser.addFile(f);
            return AnalysisReturn.IncludeFile;
        }
        return AnalysisReturn.NextHandler;
    }

    static AnalysisReturn acceptAll(scope Analyser analyser, ref FileInfo fi)
    {
        return AnalysisReturn.IncludeFile;
    }

    auto licenseChain = AnalysisChain("license", [&acceptLicense], 50);
    auto allChain = AnalysisChain("all", [&acceptAll], 20);

    auto a = new Analyser();
    a.addChain(licenseChain);
    a.addChain(allChain);
    auto l = FileInfo("LICENSES/Zlib.txt", "LICENSES/Zlib.txt");
    l.target = "main";
    a.addFile(l);
    a.process();

    auto mainBucket = a.bucket("main");
    auto allFiles = mainBucket.allFiles();
    assert(!allFiles.empty);
    auto uniqueFiles = mainBucket.uniqueFiles();
    assert(!uniqueFiles.empty);
}
