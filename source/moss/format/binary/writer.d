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

module moss.format.binary.writer;

public import std.stdio : File;

import moss.format.binary.archive_header;
import moss.format.binary : mossFormatVersionNumber;
import moss.format.binary.endianness;
import moss.format.binary.payload;

/**
 * The Writer is a low-level mechanism for writing Moss binary packages
 */
final class Writer
{

public:
    @disable this();

    /**
     * Construct a new Writer for the given filename
     */
    this(File file, uint32_t versionNumber = mossFormatVersionNumber) @trusted
    {
        _file = file;
        _header = ArchiveHeader(versionNumber);
        _header.numPayloads = 0;
    }

    /**
     * Return the filetype for this Writer
     */
    pure @property MossFileType fileType() @safe @nogc nothrow
    {
        return _header.type;
    }

    /**
     * Set the filetype for this Writer
     */
    @property void fileType(MossFileType type) @safe @nogc nothrow
    {
        _header.type = type;
    }

    ~this() @safe
    {
        close();
    }

    /**
     * Flush and close the underying file.
     */
    void close() @safe
    {
        if (!_file.isOpen())
        {
            return;
        }
        flush();
        _file.close();
    }

    /**
     * Flush all payloads to disk.
     */
    void flush() @trusted
    {
        scope auto fp = _file.getFP();

        if (!headerWritten)
        {
            writeHeaderSegment();
        }

        /**
         * Begin dumping all payloads to the stream, encoding their header first
         * and then request that they encode themselves to the stream.
         */
        foreach (p; payloads)
        {
            auto pHdr = PayloadHeader();
            pHdr.type = p.payloadType;
            pHdr.payloadVersion = p.payloadVersion;

            pHdr.toNetworkOrder();
            pHdr.encode(fp);

            /* Now encode the payload data */
            p.encode(this);
            _file.flush();
        }

        payloads = [];
    }

    /**
     * Add Payload to the stream for encoding
     */
    void addPayload(Payload p) @safe
    {
        import std.exception : enforce;

        enforce(!headerWritten, "Cannot addPayload once header has been written");
        payloads ~= p;
        _header.numPayloads++;
    }

    /**
     * Write the ArchiveHeader segment for the moss archive. This can only be
     * written once.
     */
    void writeHeaderSegment() @trusted
    {
        import std.exception : enforce;

        enforce(!headerWritten, "Cannot writeHeaderSegment twice");
        scope auto fp = _file.getFP();
        ArchiveHeader hdrCpy = _header;
        hdrCpy.toNetworkOrder();
        hdrCpy.encode(fp);

        _file.flush();
        headerWritten = true;
    }

private:

    File _file;
    ArchiveHeader _header;
    Payload[] payloads;
    bool headerWritten = false;

}
