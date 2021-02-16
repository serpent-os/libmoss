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

module moss.format.binary.payload;

public import std.stdint : uint8_t, uint16_t;

public import moss.format.binary.reader : ReaderToken;
public import moss.format.binary.writer : WriterToken;

/**
 * Specific payload type. Non-standard payloads should be indexed above
 * value 100.
 */
enum PayloadType : uint8_t
{
    /** Catch errors: Payload type should be known */
    Unknown = 0,

    /** The Metadata store */
    Meta = 1,

    /** File store, i.e. hash indexed */
    Content = 2,

    /** Map Files to Disk with basic UNIX permissions + types */
    Layout = 3,

    /** For indexing the deduplicated store */
    Index = 4,

    /* Attribute storage */
    Attributes = 5,
}

/**
 * Nearly all Payload implementations are simply Data, and can trivially
 * be manipulated in memory. However, some (such as the ContentPayload) are
 * exclusively content-based, and generally are too large to process directly
 * in memory.
 *
 * In special cases, as described above, a Payload can indicate that it is
 * backed by content only, so that the Reader/Writer can take specialised
 * approaches.
 */
enum StorageType : uint8_t
{
    Data = 0,
    Content,
}

/**
 * A Payload is an abstract supertype for all payload data within a moss
 * file or stream. In order to encode a Payload to a file, or indeed, to
 * decode a Payload from a file, you must first extend the Payload type.
 *
 * The Reader + Writer types know how to decode and encode the PayloadHeader
 * for a Payload, and will call upon the Payload implementation to finish
 * the decoding and encoding process for the data itself.
 */
abstract class Payload
{

public:

    @disable this();

    /**
     * Each implementation must call the base constructor to ensure that
     * the PayloadType property has been correctly set.
     */
    this(PayloadType payloadType, uint16_t payloadVersion,
            StorageType storageType = StorageType.Data) @safe
    {
        this.payloadType = payloadType;
        this.payloadVersion = payloadVersion;
        this.storageType = storageType;
    }

    /**
     * Return the associated PayloadType enum for encoding/decoding purposes
     */
    pure final @property PayloadType payloadType() @safe @nogc nothrow
    {
        return _payloadType;
    }

    /**
     * Return the version property of the PayloadData to facilitate
     * conditional processing
     */
    pure final @property uint16_t payloadVersion() @safe @nogc nothrow
    {
        return _payloadVersion;
    }

    /**
     * Return the StorageType used by the Payload. Typically this is the
     * Data type.
     */
    pure final @property StorageType storageType() @safe @nogc nothrow
    {
        return _storageType;
    }

    /**
     * Return the numner of records within a Data Payload
     */
    pure final @property uint32_t recordCount() @safe @nogc nothrow
    {
        return _recordCount;
    }

    /**
     * Subclasses must implement the decode method so that reading of the
     * stream data is possible.
     */
    abstract void decode(scope ReaderToken* rdr);

    /**
     * Subclasses must implement the encode method so that writing of the
     * stream data is possible.
     */
    abstract void encode(scope WriterToken* wr);

package:

    /**
     * Set the currently employed payloadVersion
     */
    pure final @property void payloadVersion(uint16_t payloadVersion) @safe @nogc nothrow
    {
        _payloadVersion = payloadVersion;
    }

    /**
     * Set the StorageType to something other than Data, the default
     */
    pure final @property void storageType(StorageType storageType) @safe @nogc nothrow
    {
        this._storageType = storageType;
    }

    /**
     * Set the number of records within the payload, implementation specific
     */
    pure final @property void recordCount(uint32_t recordCount) @safe @nogc nothrow
    {
        this._recordCount = recordCount;
    }

private:

    /**
     * Private property method to set the payloadType
     */
    @property void payloadType(PayloadType newType) @safe
    {
        import std.exception : enforce;

        enforce(newType != PayloadType.Unknown, "Cannot set an unknown PayloadType");
        _payloadType = newType;
    }

    PayloadType _payloadType = PayloadType.Unknown;
    StorageType _storageType = StorageType.Data;
    uint16_t _payloadVersion = 0;
    uint32_t _recordCount = 0;
}

public import moss.format.binary.payload.header;
