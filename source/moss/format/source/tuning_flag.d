/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.tuning_flag
 *
 * Defines the supported tuning flags per supported compiler.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.tuning_flag;

public import moss.format.source.schema;

/**
 * A CompilerFlags definition contains a set of compilation runtime flags
 * that are enabled based on a given flag being "turned on".
 *
 * This allows complex flag combinations to be enabled for fine-grained
 * control.
 */
struct CompilerFlags
{
    /** The CFLAGS variable to export */
    @YamlSchema("c") string cflags = null;

    /** The CXXFLAGS variable to export */
    @YamlSchema("cxx") string cxxflags = null;

    /** The DFLAGS variable to export */
    @YamlSchema("d") string dflags = null;

    /** The LDFLAGS variable to export */
    @YamlSchema("ld") string ldflags = null;
}

/**
 * Access pattern: Do you want LLVM or GNU?
 */
final enum Toolchain
{
    LLVM = 0,
    GNU = 1,
}

/**
 * A TuningFlag encapsulates common flags used for a given purpose,
 * such as optimising for speed, etc.
 *
 * Our type adds dependencies + accessors to abstract
 * GNU vs LLVM differences
 */
struct TuningFlag
{
    /**
     * GNU specific options
     */
    CompilerFlags gnu;

    /**
     * LLVM specific options
     */
    CompilerFlags llvm;

    /**
     * Root level flags
     */
    CompilerFlags root;

    /**
     * Return the CFLAGS
     */
    pure @property string cflags(Toolchain toolchain) @safe @nogc nothrow
    {
        if (toolchain == Toolchain.GNU && gnu.cflags != null)
        {
            return gnu.cflags;
        }
        else if (toolchain == Toolchain.LLVM && llvm.cflags != null)
        {
            return llvm.cflags;
        }
        return root.cflags;
    }

    /**
     * Return the CXXFLAGS
     */
    pure @property string cxxflags(Toolchain toolchain) @safe @nogc nothrow
    {
        if (toolchain == Toolchain.GNU && gnu.cxxflags != null)
        {
            return gnu.cxxflags;
        }
        else if (toolchain == Toolchain.LLVM && llvm.cxxflags != null)
        {
            return llvm.cxxflags;
        }
        return root.cxxflags;
    }

    /**
     * Return the DFLAGS
     */
    pure @property string dflags(Toolchain toolchain) @safe @nogc nothrow
    {
        /* FIXME: Uncomment this when we default to GDC for gcc D builds */
        /*if (toolchain == Toolchain.GNU && gnu.dflags != null)
        {
            return gnu.dflags;
        } else */
        if (toolchain == Toolchain.LLVM && llvm.dflags != null)
        {
            return llvm.dflags;
        }
        return root.dflags;
    }

    /**
     * Return the LDFLAGS
     */
    pure @property string ldflags(Toolchain toolchain) @safe @nogc nothrow
    {
        if (toolchain == Toolchain.GNU && gnu.ldflags != null)
        {
            return gnu.ldflags;
        }
        else if (toolchain == Toolchain.LLVM && llvm.ldflags != null)
        {
            return llvm.ldflags;
        }
        return root.ldflags;
    }

}
