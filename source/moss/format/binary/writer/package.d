/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.writer
 *
 * Defines Writer, which is a low-level mechanism for writing moss binary
 * .stone packages.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.writer;

public import std.stdio : File;

import moss.format.binary.archive_header;
import moss.format.binary : mossFormatVersionNumber;
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
     * Return the file type for this Writer
     */
    pure @property MossFileType fileType() @safe @nogc nothrow
    {
        return _header.type;
    }

    /**
     * Set the file type for this Writer
     */
    @property void fileType(MossFileType type) @safe @nogc nothrow
    {
        _header.type = type;
    }

    /**
     * Return the default compression type used for writing payloads.
     * This is used for every payload, and it is not currently possible
     * to set on a per-payload basis.
     *
     * Currently the default compression type is ZSTD
     */
    pure @property PayloadCompression compressionType() @safe @nogc nothrow
    {
        return _compression;
    }

    /**
     * Set the default compression type for writing payloads.
     */
    pure @property void compressionType(PayloadCompression comp) @safe @nogc nothrow
    {
        _compression = comp;
    }

    ~this() @safe
    {
        close();
    }

    /**
     * Flush and close the underlying file.
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
        import std.exception : enforce;
        import core.stdc.stdio : fseek, SEEK_CUR, SEEK_SET;

        if (!headerWritten)
        {
            writeHeaderSegment();
        }

        /* Store correctedHeaders for re-emission */
        PayloadHeader[] correctedHeaders;

        /**
         * Begin dumping all payloads to the stream, encoding their header first
         * and then request that they encode themselves to the stream.
         */
        foreach (p; payloads)
        {
            auto pHdr = PayloadHeader();
            pHdr.type = p.payloadType;
            pHdr.payloadVersion = p.payloadVersion;
            WriterToken wk;

            pHdr.compression = this.compressionType();
            final switch (pHdr.compression)
            {
            case PayloadCompression.None:
                wk = new PlainWriterToken(_file.getFP());
                break;
            case PayloadCompression.Zstd:
                wk = new ZstdWriterToken(_file.getFP());
                break;
            case PayloadCompression.Unknown:
                enforce(pHdr.compression != PayloadCompression.Unknown,
                        "Writer.flush(): Unknown PayloadCompression unsupported!");
            }
            /* Begin encoding before emitting a header and copying */
            wk.begin();
            p.encode(wk);
            wk.end();

            pHdr.plainSize = wk.sizePlain;
            pHdr.storedSize = wk.sizeCompressed;
            pHdr.checksum = wk.checksum;
            pHdr.numRecords = p.recordCount;

            correctedHeaders ~= pHdr;
        }

        /* Rewind the archive */
        auto fp = _file.getFP();
        _file.flush();
        enforce(fseek(fp, ArchiveHeader.sizeof, SEEK_SET) == 0, "flush(): Failed to rewind archive");

        /* Dump each header, skip past the content, write the new header again */
        foreach (ref hdr; correctedHeaders)
        {
            hdr.encode(fp);
            enforce(fseek(fp, hdr.storedSize, SEEK_CUR) == 0,
                    "flush(): Failed to skip PayloadHeader");
        }

        _file.flush();
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
        _header.encode(fp);

        _file.flush();
        headerWritten = true;
    }

private:

    File _file;
    ArchiveHeader _header;
    Payload[] payloads;
    bool headerWritten = false;
    PayloadCompression _compression = PayloadCompression.Zstd;

}

public import moss.format.binary.writer.token;
public import moss.format.binary.writer.zstd_token;
