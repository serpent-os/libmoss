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

/**
 * The ReaderToken abstracts access to the Reader's resources in order
 * to enable decoding for each Payload implementation
 */
public struct ReaderToken
{

}

/**
 * The PayloadEncapsulation type is used to keep track of each Payload that
 * we encounter within the stream, so that we can build a set of Payload
 * objects up.
 *
 * In turn, this allows us to have an introspective API where we can query
 * a Payload from the collection via templated APIs.
 */
package struct PayloadEncapsulation
{
    /** The actual Payload which is able to read the data */
    Payload payload;

    /** "Similar" type lookup */
    TypeInfo type;

    /** The header */
    PayloadHeader header;

    /** Where in the stream does this Payload data start? (ftell) */
    uint64_t startOffset = 0;

    /**
     * Calculate where in the stream this payload data ends
     */
    pragma(inline, true) pure @property uint64_t endOffset()
    {
        return startOffset + header.storedSize;
    }

    /**
     * Read the data into the blob, decompress and make it usable
     * for the Payload to consume
     */
    void readData(scope FILE* fp) @trusted
    {
        import std.exception : enforce;
        import core.stdc.stdio : fread, fseek, SEEK_CUR;
        import std.digest.crc : CRC64ISO;

        CRC64ISO hash;

        /* Can't decode zero data */
        if (header.plainSize < 1)
        {
            return;
        }

        final switch (header.compression)
        {
        case PayloadCompression.None:
            /* Read vanilla data in */
            data = new ubyte[header.plainSize];
            enforce(fread(data.ptr, data.length, 1, fp) == 1, "readData: fread failed");
            break;
        case PayloadCompression.Unknown:
            /* TODO: Report inability to read */
            enforce(fseek(fp, header.storedSize,
                    SEEK_CUR) == 0, "readData: fseek failed");
            break;
        case PayloadCompression.Zstd:
            auto compBytes = new ubyte[header.storedSize];
            enforce(fread(compBytes.ptr, compBytes.length, 1, fp) == 1, "readData: fread failure");

            import zstd : uncompress;

            data = cast(ubyte[]) uncompress(compBytes);
            break;
        case PayloadCompression.Zlib:
            auto compBytes = new ubyte[header.storedSize];
            enforce(fread(compBytes.ptr, compBytes.length, 1, fp) == 1, "readData: fread failure");

            import std.zlib : uncompress;

            data = cast(ubyte[]) uncompress(compBytes);
            break;
        }

        hash.put(data);

        auto hashed = hash.finish();
        enforce(hashed == header.crc64, "readData: CRC64ISO checksum failure");
    }

    /** Loaded data */
    ubyte[] data = null;

    /** Whether the data has yet been loaded */
    bool loaded = false;
}

/**
 * The Reader is a low-level mechanism for parsing Moss binary packages.
 */
final class Reader
{

private:

    File _file;
    ArchiveHeader _header;
    PayloadEncapsulation*[] payloads;

    static TypeInfo[PayloadType] registeredHandlers;

public:
    @disable this();

    /**
     * Construct a new Reader for the given filename
     */
    this(File file) @trusted
    {
        import std.exception : enforce;

        scope auto fp = file.getFP();

        _file = file;

        auto size = _file.size;
        enforce(size != 0, "Reader(): empty file");
        _header.decode(fp);

        _header.validate();

        spinPayloads();
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

        /* TODO: Remove this debug */
        import std.stdio : writeln;

        writeln("Registering Payload Handler: ", typeid(P).toString, " for type: ", type);
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
        static const auto genType = typeid(T);
        foreach (ref p; payloads)
        {
            if (genType == p.type)
            {
                return cast(T) p.payload;
            }
        }

        return null;
    }

private:

    /**
     * Begin reading through each of the payload headers and begin
     * associating Payload instances with them, loaded into a slice.
     */
    void spinPayloads() @trusted
    {
        import std.exception : enforce;
        import core.stdc.stdio : ftell, fseek, SEEK_SET;
        import std.stdio : writeln;

        foreach (payloadIndex; 0 .. _header.numPayloads)
        {
            PayloadHeader pHdr;
            scope auto fp = _file.getFP();
            pHdr.decode(fp);

            /* Record offsets */
            const auto whence = ftell(fp);
            enforce(whence > 0, "spinPayloads: ftell failure");

            /* Store the Payload now */
            auto pEncap = new PayloadEncapsulation();
            pEncap.header = pHdr;
            pEncap.startOffset = whence;
            pEncap.payload = getPayloadImplForType(pHdr.type);
            payloads ~= pEncap;

            writeln(*pEncap);

            /* Set search type */
            if (pEncap.payload !is null)
            {
                pEncap.type = registeredHandlers[pHdr.type];
            }

            /* TODO: Wrap the underlying buffer for ReaderToken */
            ReaderToken rdr;

            /* Always try to load Data segments */
            if (pEncap.payload !is null && pEncap.payload.storageType == StorageType.Data)
            {
                pEncap.readData(fp);
                pEncap.payload.decode(&rdr);
            }
            else
            {
                /* Don't skip last payload, micro optimisation for Content loading */
                if (payloadIndex == _header.numPayloads - 1)
                {
                    continue;
                }

                /* Otherwise, blindly seek */
                enforce(fseek(fp, whence + pHdr.storedSize, SEEK_SET) == 0,
                        "spinPayloads: fseek failed");
            }

        }
    }
}
