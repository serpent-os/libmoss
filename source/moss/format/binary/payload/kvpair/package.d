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

module moss.format.binary.payload.kvpair;

public import std.stdint;
public import moss.format.binary.payload;

import moss.format.binary.endianness;

/**
 * A KvDatum is a simple struct recording the key and value lengths within
 * the database. It is always 16-bytes in length and properly encoded.
 */
extern (C) struct KvDatum
{
    /** Length of the datum key */
    @AutoEndian uint64_t keyLength;

    /** Length of the datum value */
    @AutoEndian uint64_t valueLength;
}

static assert(KvDatum.sizeof == 16, "KvDatum should only ever be 16-bytes");

/**
 * The KvPairPayload is an abstract mechanism by which payloads can be implemented
 * in a key-value database fashion. It is expected that the primary "Key" of a
 * payload is properly encoded as ubyte[], also true for the value.
 *
 * Within moss, the primary use of KvPairPayload is in combination with the
 * Serpent ECS project, in order to provide a quick database that can be
 * encoded as a moss archive.
 *
 * Implementations should still ensure they register their specific type and
 * version with the Reader API in a static constructor.
 */
abstract class KvPairPayload : Payload
{
    @disable this();

    /**
     * Super constructor for KvPairPayload which will pass the type and
     * version up the chain, whilst enforcing the payload storage type
     * is always set to *data*.
     *
     * It is not appropriate to use a KvPairPayload as a large document
     * store. Instead the correct store APIs should be used in conjunction
     * with a KvPairPayload as a lookup mechanism.
     */
    this(PayloadType payloadType, uint16_t payloadVersion) @safe
    {
        super(payloadType, payloadVersion, StorageType.Data);
    }

    /**
     * Encoding is not yet implemented
     */
    final override void encode(scope WriterToken wr)
    {

    }

    /**
     * Decoding is not yet implemented
     */
    final override void decode(scope ReaderToken rdr)
    {

    }
}
