/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.analysis.chain
 *
 * Defines the notion of an extensible analysis chain, which can apply
 * successive rules (via function pointers) in order to determine the
 * type of build artifacts and whether to include them in a given
 * (sub)package or not.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.analysis.chain;

public import moss.deps.analysis.analyser : Analyser;
public import moss.deps.analysis.fileinfo;

/**
 * Chains can force the control flow depending on their return status
 */
enum AnalysisReturn
{
    /**
     * Pass this file onto the next handler. We're uninterested in it
     */
    NextHandler = 0,

    /**
     * Move to the next function in this chain.
     */
    NextFunction,

    /**
     * Ignore this file, nobody will want it
     */
    IgnoreFile,

    /**
     * End chain execution, include the file
     */
    IncludeFile,
}

/**
 * An analysis function may use the incoming FileInfo to discover further
 * details about it.
 */
alias AnalysisFunc = AnalysisReturn function(scope Analyser analyser, ref FileInfo fi);

/**
 * An AnalysisChain is simply a named set of handlers which control the flow
 * for analysis evaluation.
 */
public struct AnalysisChain
{
    /**
     * Name of the handler
     */
    const(string) name;

    /**
     * Set of functions to control flow
     */
    AnalysisFunc[] funcs;

    /**
     * Higher priority always runs first
     */
    ulong priority = 0;
}

/**
 * End a chain by dropping a file
 */
public pure AnalysisReturn dropFile(scope Analyser analyser, ref FileInfo fileInfo)
{
    return AnalysisReturn.IgnoreFile;
}

/**
 * End a chain with including a file
 */
public pure AnalysisReturn includeFile(scope Analyser analyser, ref FileInfo fileInfo)
{
    return AnalysisReturn.IncludeFile;
}
