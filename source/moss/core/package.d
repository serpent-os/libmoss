/* SPDX-License-Identifier: Zlib */

/**
 * Moss Core
 *
 * Contains useful shared core moss functionality and basic building blocks
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: ZLib
 */
module moss.core;

import core.stdc.stdlib : EXIT_FAILURE, EXIT_SUCCESS;

public import moss.core.encoding;
public import moss.core.util;
public import moss.core.platform;
public import moss.core.store;

public import std.stdint : uint8_t;

/** Current Moss Version */
const Version = "0.0.1";

public import moss.core.platform;

/**
 * Currently just wraps the two well known exit codes from the
 * C standard library. We will flesh this out with specific exit
 * codes to facilitate integration with scripts and tooling.
 */
enum ExitStatus
{
    Failure = EXIT_FAILURE,
    Success = EXIT_SUCCESS,
}

/**
 * Various parts of the moss codebases perform file copies, and should all
 * use a standard chunk size of 4mib.
 */
public immutable auto ChunkSize = 4 * 1024 * 1024;

/**
 * Base of all our required directories
 */
const RootTree = "os";

/**
 * The HashStore directory, used for deduplication purposes
 */
const HashStore = RootTree ~ "/store";

/**
 * The RootStore directory contains our OS image root
 */
const RootStore = RootTree ~ "/root";

/**
 * The DownloadStore directory contains all downloads
 */
const DownloadStore = RootTree ~ "/download";

/**
 * Well known file type
 */
enum FileType : uint8_t
{
    /* Catch errors */
    Unknown = 0,

    /** Regular file **/
    Regular = 1,

    /** Symbolic link to another location */
    Symlink = 2,

    /** Directory */
    Directory = 3,

    /** Character Device */
    CharacterDevice = 4,

    /** Block device */
    BlockDevice = 5,

    /** Fifo pipe */
    Fifo = 6,

    /** Socket */
    Socket = 7,
}
