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

    /**
     * Each implementation must call the base constructor to ensure that
     * the PayloadType property has been correctly set.
     */
    this(PayloadType payloadType) @safe
    {
        this.payloadType = payloadType;
    }

    /**
     * Return the associated PayloadType enum for encoding/decoding purposes
     */
    pure final @property PayloadType payloadType() @safe @nogc nothrow
    {
        return _payloadType;
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

    PayloadType _payloadType;
}

public import moss.format.binary.payload.header;
