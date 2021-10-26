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

module moss.deps.analysis.analyser;

public import moss.deps.analysis.bucket;
public import moss.deps.analysis.chain;

import std.exception : enforce;
import std.string : format;
import std.container.rbtree;

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
        pendingFiles ~= file;

        /* Ensure bucket exists! */
        if (file.target in _buckets)
        {
            return;
        }
        _buckets[file.target] = new AnalysisBucket(file.target);
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
     * Very simple method to process all incoming files 
     */
    void process()
    {
        auto numFiles = pendingFiles.length;
        import std.algorithm : remove;

        while (numFiles > 0)
        {
            auto fi = pendingFiles[0];
            immutable auto fileAction = processOne(fi);

            /* remove file from pending set */
            pendingFiles = pendingFiles.remove(0);

            final switch (fileAction)
            {
            case Action.IncludeFile:
                _buckets[fi.target].add(fi);
                break;
            case Action.IgnoreFile:
                break;
            case Action.Unhandled:
                throw new Exception("Unhandle file: %s".format(fi.fullPath));
            }

            numFiles = pendingFiles.length;
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
        import std.algorithm : remove;

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
}

unittest
{
    static AnalysisReturn acceptLicense(scope Analyser analyser, in FileInfo fi)
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

    static AnalysisReturn acceptAll(scope Analyser analyser, in FileInfo fi)
    {
        return AnalysisReturn.IncludeFile;
    }

    auto licenseChain = AnalysisChain("license", [&acceptLicense], 50);
    auto allChain = AnalysisChain("all", [&acceptAll], 20);

    auto a = new Analyser();
    a.addChain(licenseChain);
    a.addChain(allChain);
    auto l = FileInfo("LICENSE", "LICENSE");
    l.target = "main";
    a.addFile(l);
    a.process();
}
