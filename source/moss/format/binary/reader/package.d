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

module moss.format.binary.reader;

public import std.stdio : File;
public import moss.format.binary.archive_header;

import moss.format.binary.endianness;
import moss.format.binary.payload;
import std.stdint : uint64_t;

import std.mmfile : MmFile;

/**
 * Each PayloadWrapper manages an instance of Payload, which can be dynamically
 * initialised with the appropriate storage type.
 *
 * It is also used to track the offsets for a Payload blob for extraction to
 * actually work.
 */
package struct PayloadWrapper
{

    /**
     * Return the start offset for the Payload
     */
    pragma(inline, true) pure @property uint64_t start() @safe @nogc nothrow
    {
        return _start;
    }

    /**
     * Set the start offset for the Payload
     */
    pragma(inline, true) pure @property void start(uint64_t start) @safe @nogc nothrow
    {
        _start = start;
    }

    /**
     * Return the end offset for the Payload
     */
    pragma(inline, true) @property uint64_t end() @safe @nogc nothrow
    {
        return _start + header.storedSize;
    }

    /**
     * Return the underlying payload instance
     */
    pragma(inline, true) pure @property Payload payload() @safe @nogc nothrow
    {
        return _payload;
    }

    /**
     * Update the Payload instance
     */
    pragma(inline, true) pure @property void payload(Payload p) @safe @nogc nothrow
    {
        _payload = p;
    }

    /**
     * Expose Header property
     */
    pragma(inline, true) pure @property ref PayloadHeader header() @safe @nogc nothrow return 
    {
        return _header;
    }

    /**
     * Set the header explicitly
     */
    pragma(inline, true) pure @property void header(PayloadHeader header) @safe @nogc nothrow
    {
        _header = header;
    }

    /**
     * Return true if we've been loaded before
     */
    pragma(inline, true) pure @property bool loaded() @safe @nogc nothrow
    {
        return _loaded;
    }

    /**
     * Updated loaded status
     */
    pragma(inline, true) pure @property void loaded(bool b) @safe @nogc nothrow
    {
        _loaded = b;
    }

    TypeInfo type;

private:

    uint64_t _start = 0;
    PayloadHeader _header;
    Payload _payload;
    bool _loaded = false;
}

/**
 * The Reader is a low-level mechanism for parsing Moss binary packages.
 */
public final class Reader
{
    @disable this();

    /**
     * Construct a new Reader for the given filename
     */
    this(File file) @trusted
    {
        import std.exception : enforce;

        _file = file;
        mappedFile = new MmFile(_file);

        fileLength = _file.size;
        enforce(fileLength != 0, "Reader(): empty file");

        /* Read through the header */
        readPointer = 0;
        readPointer += _header.decode(cast(ubyte[]) mappedFile[readPointer .. $]);
        _header.validate();

        iteratePayloads();
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
        _file.close();
    }

    /**
     * Register a payload type with the Reader system.
     *
     * When a Payload type is registered according to the Payload implementation,
     * we can ensure that automatic decoding of Payloads with the correct implementation
     * is possible.
     */
    static void registerPayloadType(P : Payload)(PayloadType type) @safe
    {
        import std.exception : enforce;

        enforce(!(type in registeredHandlers),
                "registerPayloadType: Cannot double-register a handler");

        registeredHandlers[type] = typeid(P);
    }

    /**
     * Tries to return a new instance of the Payload implementation for the given Payload
     * type.
     * If the type is not known to us, we'll return null and not support automatic
     * reading of the payload data.
     */
    static Payload getPayloadImplForType(PayloadType type) @trusted
    {
        import std.exception : enforce;
        import std.stdio : writeln;

        /* It's ok to return NULL */
        if (!(type in registeredHandlers))
        {
            return null;
        }

        auto tph = registeredHandlers[type];
        auto pload = cast(Payload) Object.factory(tph.toString);
        enforce(pload.payloadType == type,
                "getPayloadImplForType: Unsupported implementation in " ~ tph.toString);

        return pload;
    }

    /**
     * Return first matching Payload instance type or null if not found
     */
    T payload(T : Payload)()
    {
        foreach (ref w; wrappers)
        {
            if (w.type == typeid(T))
            {
                if (w.payload !is null && !w.loaded && w.payload.storageType == StorageType.Data)
                {
                    loadPayload(w);
                }
                return cast(T) w.payload;
            }
        }

        return null;
    }

    /**
     * The headers property returns a slice of the headers as found in the stream,
     * sequentially.
     */
    @property auto headers() @safe nothrow
    {
        import std.algorithm : map;

        return wrappers.map!((w) => w.header());
    }

    /**
     * Assuming the Payload supports Content storage, unpackContent will simply
     * decompress the entire contents to the output file name. This is primarily
     * useful for the ContentPayload, but may be used for any files-as-a-payload
     * usecase.
     */
    void unpackContent(scope Payload p, const(string) destFile) @trusted
    {
        import std.exception : enforce;
        import std.string : format;

        enforce(p.storageType == StorageType.Content,
                "Reader.unpackContent(): %s doesn't support Content Storage".format(typeid(p).name));

        File outputFile = File(destFile, "wb");

        scope (exit)
        {
            outputFile.close();
        }
        return unpackContent(p, outputFile);
    }

    /**
     * unpackContent will write the entire contents of the extraction section to
     * the given file
     */
    void unpackContent(scope Payload p, File outputFile) @trusted
    {
        import std.exception : enforce;
        import std.string : format;
        import std.conv : to;

        /* Find the correct wrapper to get the header, etc. */
        PayloadWrapper* wrapper = null;
        foreach (wr; wrappers)
        {
            if (p !is null && wr.payload == p)
            {
                wrapper = wr;
                break;
            }
        }
        enforce(wrapper !is null,
                "Reader.unpackContent(): No known PayloadHeader for %s".format(typeid(p).name));

        ReaderToken rt = null;
        ubyte[] rangedData = cast(ubyte[]) mappedFile[wrapper.start .. wrapper.end];

        switch (wrapper.header.compression)
        {
        case PayloadCompression.Zstd:
            rt = new ZstdReaderToken(rangedData);
            break;
        case PayloadCompression.None:
        case PayloadCompression.Unknown:
            rt = new PlainReaderToken(rangedData);
            break;
        default:
            throw new Error("Reader.unpackContent(): Cannot read compression type: %s".format(
                    to!string(wrapper.header.compression)));
        }

        rt.header = wrapper.header;
        uint64_t readTotal = rt.header.plainSize;
        uint64_t readCurrent = 0;
        while (readCurrent < readTotal)
        {
            static const auto chunkSize = 128 * 1024;
            auto remaining = readTotal - readCurrent;
            auto readSize = remaining <= chunkSize ? remaining : chunkSize;
            ubyte[] readData = rt.readData(readSize);
            outputFile.rawWrite(readData);
            readCurrent += readData.length;
        }

        enforce(readCurrent == readTotal, "Reader: Invalid read in unpackContent");

        rt.finish();
        enforce(rt.crc64iso == wrapper.header.crc64,
                "Reader: Invalid checksum on payload %s".format(to!string(wrapper.type)));
    }

    /**
     * Return a copy of the main header struct
     */
    pure @property ArchiveHeader archiveHeader() @safe @nogc nothrow
    {
        return _header;
    }

    /**
     * Return the underlying moss file type, i.e. package, database, etc.
     */
    pure @property MossFileTyoe fileType() @safe @nogc nothrow
    {
        return _header.fileType;
    }

private:

    File _file;
    MmFile mappedFile;
    ArchiveHeader _header;
    PayloadWrapper*[] wrappers;

    ulong readPointer = 0;
    ulong fileLength = 0;

    static TypeInfo[PayloadType] registeredHandlers;

    /**
     * Walk through the payloads in the stream and process them
     */
    void iteratePayloads() @trusted
    {
        import std.exception : enforce;

        /* Read numPayloads worth of payloads. */
        foreach (payloadIndex; 0 .. _header.numPayloads)
        {
            PayloadHeader ph;
            readPointer += ph.decode(cast(ubyte[]) mappedFile[readPointer .. $]);

            auto wrap = new PayloadWrapper();
            wrap.header = ph;
            wrap.start = readPointer;

            /* Instaniate the Payload object */
            wrap.payload = getPayloadImplForType(wrap.header.type);
            if (wrap.payload !is null)
            {
                wrap.type = registeredHandlers[wrap.header.type];
            }

            /* Skip to next PayloadHeader now for next read */
            readPointer += ph.storedSize;
            enforce(readPointer <= fileLength,
                    "Reader.iteratePayloads(): Insufficient storage for reading Payloads");

            wrappers ~= wrap;
        }
        enforce(readPointer == fileLength, "Reader.iteratePayloads(): Garbage at end of stream");
    }

    /**
     * Load the specified payload on demand
     *
     * We only load a Payload once and only for a Data type storage.
     */
    void loadPayload(scope PayloadWrapper* wrapper) @trusted
    {
        import std.string : format;
        import std.exception : enforce;
        import std.conv : to;

        scope (exit)
        {
            wrapper.loaded = true;
        }

        /* TODO: Initialise a ReaderToken based on the range of available data */
        ReaderToken rt = null;
        ubyte[] rangedData = cast(ubyte[]) mappedFile[wrapper.start .. wrapper.end];

        switch (wrapper.header.compression)
        {
        case PayloadCompression.Zstd:
            rt = new ZstdReaderToken(rangedData);
            break;
        case PayloadCompression.None:
        case PayloadCompression.Unknown:
            rt = new PlainReaderToken(rangedData);
            break;
        default:
            throw new Error("Reader.loadPayload(): Cannot read compression type: %s".format(
                    to!string(wrapper.header.compression)));
        }

        rt.header = wrapper.header;
        wrapper.payload.decode(rt);
        rt.finish();
        enforce(rt.crc64iso == wrapper.header.crc64,
                "Reader: Invalid checksum on payload %s".format(to!string(wrapper.type)));
    }
}

public import moss.format.binary.reader.token;
