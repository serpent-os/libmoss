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
     * Implementations should simply override encodeData to return the newly
     * compressed data using whatever method is deemed appropriate.
     * For "no compression" we just return the same data.
     */
    abstract ubyte[] encodeData(ref ubyte[] data) @trusted
    {
        return data;
    }

    /**
     * Flush all encodings, returning the remainder
     */
    abstract ubyte[] flushData() @trusted
    {
        return null;
    }

    /**
     * Append data to the stream, updating the known sizes + checksum
     */
    final void appendData(ubyte[] data)
    {
        import std.exception : enforce;
        import core.stdc.stdio : fwrite;

        _sizePlain += data.length;
        auto encoded = encodeData(data);
        _sizeCompressed += encoded.length;
        checksumHelper.put(encoded);

        enforce(fp !is null, "WriterToken.appendData(): No file pointer!");

        /* Dump what we have to the stream */
        enforce(fwrite(encoded.ptr, ubyte.sizeof, encoded.length,
                fp) == encoded.length, "WriterToken.appendData(): Failed to write data");
    }

    /**
     * Flush any remaining data to the stream
     */
    final void flush()
    {
        import core.stdc.stdio : fwrite;
        import std.exception : enforce;

        auto flushedSet = flushData();
        if (flushedSet is null || flushedSet.length < 1)
        {
            return;
        }

        /* Got something left to write... */
        _sizeCompressed += flushedSet.length;
        checksumHelper.put(flushedSet);

        enforce(fp !is null, "WriterToken.flush(): No file pointer!");

        /* Dump what we have to the stream */
        enforce(fwrite(flushedSet.ptr, ubyte.sizeof, flushedSet.length,
                fp) == flushedSet.length, "WriterToken.end(): Failed to write data");
    }

    /**
     * Append a single byte to the stream.
     */
    final void appendData(ubyte datum)
    {
        ubyte[1] data = [datum];
        appendData(data);
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

    override ubyte[] encodeData(ref ubyte[] data) @safe @nogc nothrow
    {
        return data;
    }

    override ubyte[] flushData() @safe @nogc nothrow
    {
        return null;
    }
}
