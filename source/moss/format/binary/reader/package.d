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
import xxhash : XXH3_64;

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

        checksumHelper = new XXH3_64();
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
        _file.close();
    }

    /**
     * Set userdata up
     */
    void setUserData(P : Payload)(void* userData) @trusted
    {
        userdataPointers[typeid(P)] = userData;
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
     * Return all matching payloads as a range
     */
    auto payloads(T : Payload)()
    {
        import std.algorithm : filter, map;

        iteratePayloads();

        auto filterFunc(scope PayloadWrapper* w)
        {
            return w.type == typeid(T);
        }

        return wrappers.filter!(filterFunc)
            .map!((w) => PayloadReturn(this, w))
            .map!((p) => p.payload);
    }

    /**
     * Return the first payload matching the given type
     */
    T payload(T : Payload)()
    {
        import std.range : take;

        auto payloads = this.payloads!T();
        return payloads.empty ? null : cast(T) payloads.take(1).front;
    }

    /**
     * The headers property returns a slice of the headers as found in the stream,
     * sequentially.
     */
    @property auto headers() @safe
    {
        iteratePayloads();

        import std.algorithm : map;

        return wrappers.map!((w) => PayloadReturn(this, w));
    }

    /**
     * Assuming the Payload supports Content storage, unpackContent will simply
     * decompress the entire contents to the output file name. This is primarily
     * useful for the ContentPayload, but may be used for any files-as-a-payload
     * use case.
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
        validateChecksum(wrapper, rangedData);

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
    pure @property MossFileType fileType() @safe @nogc nothrow
    {
        return _header.type;
    }

private:

    File _file;
    MmFile mappedFile;
    ArchiveHeader _header;
    PayloadWrapper*[] wrappers;
    XXH3_64 checksumHelper;

    ulong readPointer = 0;
    ulong fileLength = 0;

    bool didIterate = false;

    void*[TypeInfo] userdataPointers;

    static TypeInfo[PayloadType] registeredHandlers;

    /**
     * Walk through the payloads in the stream and process them
     */
    void iteratePayloads() @trusted
    {
        if (didIterate)
        {
            return;
        }
        didIterate = true;

        import std.exception : enforce;

        /* Read numPayloads worth of payloads. */
        foreach (payloadIndex; 0 .. _header.numPayloads)
        {
            PayloadHeader ph;
            readPointer += ph.decode(cast(ubyte[]) mappedFile[readPointer .. $]);

            auto wrap = new PayloadWrapper();
            wrap.header = ph;
            wrap.start = readPointer;

            /* Instantiate the Payload object */
            wrap.payload = getPayloadImplForType(wrap.header.type);
            if (wrap.payload !is null)
            {
                wrap.type = registeredHandlers[wrap.header.type];

                auto tpid = typeid(wrap.payload);
                if (tpid in userdataPointers)
                {
                    wrap.payload.userData = userdataPointers[tpid];
                }
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
        import std.conv : to;
        import std.string : format;

        scope (exit)
        {
            wrapper.loaded = true;
        }

        /* Map available data to byte range (0-copy) */
        ReaderToken rt = null;
        ubyte[] rangedData = cast(ubyte[]) mappedFile[wrapper.start .. wrapper.end];

        validateChecksum(wrapper, rangedData);

        /* Initialise a ReaderToken based on the range of available data */
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
    }

    void validateChecksum(scope PayloadWrapper* wrapper, ref scope ubyte[] data)
    {
        import std.string : format;
        import std.exception : enforce;
        import std.conv : to;
        import moss.core : ChunkSize;
        import std.range : chunks;
        import std.algorithm : each;

        /* Read ahead and verify the CRC64ISO before actually dealing with contents */
        data.chunks(ChunkSize).each!((b) => checksumHelper.put(b));
        auto result = checksumHelper.finish();

        enforce(result == wrapper.header.checksum,
                "Reader: Invalid checksum on payload %s, expected '%s', got '%s'".format(
                    to!string(wrapper.type),
                    to!string(wrapper.header.checksum), to!string(result)));
    }

}

/**
 * Simple type to wrap the payload functions and make them automatically
* load on demand
*/
public struct PayloadReturn
{
    PayloadHeader pt;
    alias pt this;

    @disable this();

package:

    /**
     * Construct a new PayloadReturn type
     */
    this(Reader refOwner, PayloadWrapper* wrapper)
    {
        this.refOwner = refOwner;
        this.wrapper = wrapper;
        this.pt = wrapper.header;
    }

public:

    /**
     * Return a payload and load it when needed
     */
    @property Payload payload() @safe
    {
        if (wrapper.payload !is null && !wrapper.loaded
                && wrapper.payload.storageType == StorageType.Data)
        {
            refOwner.loadPayload(wrapper);
        }
        return wrapper.payload;
    }

private:

    PayloadWrapper* wrapper = null;
    Reader refOwner = null;
}

public import moss.format.binary.reader.token;
