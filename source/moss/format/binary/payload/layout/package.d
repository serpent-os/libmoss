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

module moss.format.binary.payload.layout;

public import moss.format.binary.payload;

/**
 * The currently writing version for LayoutPayload
 */
const uint16_t layoutPayloadVersion = 1;

/**
 * A LayoutPayload contains a series of definintions on how to apply a particular
 * filesystem layout for a given package to the target filesystem. It is used
 * in conjunction with the cache assets stored and referenced within ContentPayload
 * and IndexPayload as the final step of making package assets available.
 */
final class LayoutPayload : Payload
{

public:

    /**
     * Create a new instance of LayoutPayload
     */
    this() @safe
    {
        super(PayloadType.Layout, layoutPayloadVersion);
    }

    /**
     * We ensure we're registered correctly with the Reader subsystem
     */
    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!LayoutPayload(PayloadType.Layout);
    }

    /**
     * Encode the LayoutPayload to the WriterToken
     */
    override void encode(scope WriterToken* wr) @trusted
    {
        /* Ensure every set is encoded via WriterToken API */
        foreach (index; 0 .. sets.length)
        {
            auto set = &sets[index];
            set.encode(wr);
        }
    }

    /**
     * Decode the LayoutPayload from the ReaderToken
     */
    override void decode(scope ReaderToken* rdr) @trusted
    {
        /* Match number of records */
        recordCount = rdr.header.numRecords;

        foreach (recordIndex; 0 .. recordCount)
        {
            sets ~= EntrySet();
            auto length = cast(long) sets.length;
            auto set = &sets[length - 1];
            set.decode(rdr);

            import std.stdio;

            writeln(*set);
        }
    }

    /**
     * Add a layout entry. Every entry MUST have at least a source OR target,
     * they cannot both be empty.
     *
     * For symlinks, source AND target must be set.
     * For special files, entry.tag MUST be non-0, and source NULL
     * For directories, target must be set and source MUST be null
     * For regular files, source MUST be an ID, and target MUST be NULL.
     */
    void addLayout(LayoutEntry entry, string source, string target = null)
    {
        import std.exception : enforce;
        import moss.format.binary : FileType;

        sets ~= EntrySet();
        auto length = cast(long) sets.length;
        auto set = &sets[length - 1];

        set.entry = entry;
        set.source = source;
        set.target = target;

        final switch (entry.type)
        {
        case FileType.Regular:
            enforce(source !is null && target !is null,
                    "addLayout: Regular file needs SOURCE and TARGET");
            break;
        case FileType.Symlink:
            enforce(source !is null && target !is null,
                    "addLayout: Symlink needs SOURCE and TARGET");
            break;
        case FileType.Directory:
            enforce(source is null && target !is null,
                    "addLayout: Directory needs TARGET only");
            break;
        case FileType.CharacterDevice:
        case FileType.BlockDevice:
            enforce(source is null
                    && target !is null, "addLayout: Device needs TARGET only");
            enforce(entry.tag != 0, "addLayout: Device tag (origin) not set");
            break;
        case FileType.Fifo:
            enforce(source !is null && target !is null,
                    "addLayout: FIFO needs TARGET only");
            break;
        case FileType.Socket:
            enforce(source is null && target !is null,
                    "addLayout: Socket needs TARGET only");
            break;
        case FileType.Unknown:
            enforce(0 == 1, "Refusing to add unknown FileType");
            break;
        }

        recordCount = cast(uint32_t) length;

        import std.stdio : writeln;

        writeln(*set);
    }

private:

    EntrySet[] sets;
}

public import moss.format.binary.payload.layout.entry;
public import moss.format.binary.payload.layout.entryset;
