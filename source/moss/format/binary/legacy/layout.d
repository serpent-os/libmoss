/*
 * This file is part of moss-format.
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

module moss.format.binary.legacy.layout;

public import std.stdint;

import moss.format.binary.endianness;

/**
 * A FileType is a simple tagging mechanism so that we're able to record the
 * destination file type (*Nix) in the layout, so that it may be reapplied
 * upon extraction.
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

/**
 * A LayoutEntry is a multipart key that defines the origin of
 * a constructed path.
 *
 * The corresponding value of the key will contain two values,
 * the origin, and the target. In all regular file cases, the
 * origin will be a hash ID so that files may be linked out from
 * the system hash store.
 *
 * In the instance of directories, the origin will be blank and skipped.
 * In the case of symlinks, the origin will be the source of the symlink.
 * And finally, for special files (mkdev) the origin will be the uint32_t
 * device number encoded as a uint32_t.
 *
 * The tag field is reserved for internal use, allowing individual paths
 * to be flagged as a certain *kind* of file, which may in turn trigger
 * some kind of action.
 */
extern (C) struct LayoutEntry
{
align(1):

    /** 8-bytes, endian aware, UNIX timestamp */
    @AutoEndian uint64_t time;

    /** 4-bytes, endian aware, owning user ID */
    @AutoEndian uint32_t uid;

    /** 4-bytes, endian aware, owning group ID */
    @AutoEndian uint32_t gid;

    /** 4-bytes, endian aware, mode/permissions */
    @AutoEndian uint32_t mode;

    /** 4-bytes, endian aware, tag for the file meta type (usage) */
    @AutoEndian uint32_t tag;

    /** 2-bytes, endian aware, length for the source (ID) parameter */
    @AutoEndian uint16_t sourceLength; /* 2 bytes */

    /** 2-bytes, endian aware, length for the target (path) parameter */
    @AutoEndian uint16_t targetLength; /* 2 bytes */

    /** 1 byte, type of the destination file */
    FileType type;

    /** 3-byte array, reserved padding */
    ubyte[3] padding;

    /**
     * Encode the LayoutEntry to the underlying byte buffer
     */
    void encode(ref ubyte[] p) @trusted nothrow
    {
        this.toNetworkOrder();
        p ~= (cast(ubyte*)&time)[0 .. time.sizeof];
        p ~= (cast(ubyte*)&uid)[0 .. uid.sizeof];
        p ~= (cast(ubyte*)&mode)[0 .. mode.sizeof];
        p ~= (cast(ubyte*)&tag)[0 .. tag.sizeof];
        p ~= (cast(ubyte*)&sourceLength)[0 .. sourceLength.sizeof];
        p ~= (cast(ubyte*)&targetLength)[0 .. targetLength.sizeof];
        p ~= (cast(ubyte*)&type)[0 .. type.sizeof];
        p ~= padding;
        this.toHostOrder();
    }
}

static assert(LayoutEntry.sizeof == 32,
        "LayoutEntry size must be 32 bytes, not " ~ LayoutEntry.sizeof.stringof ~ " bytes");
