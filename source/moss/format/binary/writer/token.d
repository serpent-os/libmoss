/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.writer.token
 *
 * Defines a WriterToken, which knows how to perform various operations,
 * such as hash verification, compression etc.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.writer.token;

import core.stdc.stdio : FILE;
import xxhash : XXH3_64;
import std.stdio : File;
import std.algorithm : each;

import moss.format.binary.payload.header;

/**
 * A WriterToken implementation knows how to perform various compression
 * techniques, CRC64ISO verification, etc.
 */
public abstract class WriterToken
{

    @disable this();

    /**
     * Super constructor for all WriterTokens.
     */
    this(FILE* fp) @trusted
    {
        this._fp = fp;
        checksumHelper = new XXH3_64();
    }

    /**
     * Copy an entire input file, performing any modifications or
     * compression.
     *
     * This is largely provided for the zstd implementation to optimise
     * compression of the large content payload.
     */
    abstract void appendFile(in string path);

    /**
     * Implementations must perform their encoding logic and
     * then call updateStream with the encoded data.
     */
    abstract void appendData(ubyte[] data);

    /** 
     * Implementations must append any buffered data now
     */
    abstract void flush();

    /**
     * Append a single byte to the stream.
     */
    final void appendData(ubyte datum)
    {
        appendData([datum]);
    }

    final void updateStream(ulong uncompressedLength, ubyte[] compressedData)
    {
        import std.exception : enforce;
        import core.stdc.stdio : fwrite;

        _sizePlain += uncompressedLength;
        _sizeCompressed += compressedData.length;
        checksumHelper.put(compressedData);

        enforce(fp !is null, "WriterToken.updateStream(): No file pointer!");

        /* Dump what we have to the stream */
        enforce(fwrite(compressedData.ptr, ubyte.sizeof, compressedData.length,
                fp) == compressedData.length, "WriterToken.updateStream(): Failed to write data");
    }

package:

    /**
     * Begin encoding by emitting a Dumb header
     */
    final void begin() @trusted
    {
        /* Forcibly encode a dumb header for this session */
        auto hdr = PayloadHeader();
        hdr.type = PayloadType.Dumb;
        hdr.compression = PayloadCompression.None;
        hdr.encode(fp);

        /* Reset current knowledge. */
        sizePlain = 0;
        sizeCompressed = 0;
        checksum = [0, 0, 0, 0, 0, 0, 0, 0];
    }

    /**
     * End encoding by flushing underlying streams
     */
    final void end() @trusted
    {
        flush();
        checksum = checksumHelper.finish();
    }

    /**
     * Return the file pointer property
     */
    pragma(inline, true) pure final @property FILE* fp() @safe @nogc nothrow
    {
        return _fp;
    }

    /**
     * Return the total size when decompressed
     */
    pragma(inline, true) pure final @property uint64_t sizePlain() @safe @nogc nothrow
    {
        return _sizePlain;
    }

    /**
     * Return the total size when compressed
     */
    pragma(inline, true) pure final @property uint64_t sizeCompressed() @safe @nogc nothrow
    {
        return _sizeCompressed;
    }

    /**
     * Return the calculated XXHash3!64 value
     */
    pragma(inline, true) pure final @property ubyte[8] checksum() @safe @nogc nothrow
    {
        return _checksum;
    }

private:

    /**
     * Update the file pointer property
     */
    pragma(inline, true) pure @property void fp(FILE* fp) @safe @nogc nothrow
    {
        _fp = fp;
    }

    /**
     * Set the compressed size
     */
    pragma(inline, true) pure @property void sizeCompressed(uint64_t newSize) @safe @nogc nothrow
    {
        _sizeCompressed = newSize;
    }

    /**
     * Set the plain size
     */
    pragma(inline, true) pure @property void sizePlain(uint64_t newSize) @safe @nogc nothrow
    {
        _sizePlain = newSize;
    }

    /**
     * Set the known checksum value
     */
    pragma(inline, true) pure @property void checksum(ubyte[8] newChecksum) @safe @nogc nothrow
    {
        _checksum = newChecksum;
    }

    FILE* _fp = null;
    XXH3_64 checksumHelper;
    uint64_t _sizeCompressed = 0;
    uint64_t _sizePlain = 0;
    ubyte[8] _checksum = [0, 0, 0, 0, 0, 0, 0, 0];
}

/**
 * A PlainWriterToken encodes directly to the stream without any compression.
 */
final class PlainWriterToken : WriterToken
{

    @disable this();

    /**
     * Construct new PlainWriterToken from the given file pointer
     */
    this(FILE* fp) @safe
    {
        super(fp);
    }

    /**
     * Merge file (by chunks) into underlying stream
     */
    override void appendFile(in string path)
    {
        File fi = File(path, "rb");
        scope (exit)
        {
            fi.close();
        }
        fi.byChunk(128 * 1024).each!((b) => super.updateStream(b.length, b));
    }

    override void appendData(ubyte[] data)
    {
        super.updateStream(data.length, data);
    }

    /**
     * No-op
     */
    override void flush()
    {

    }
}
