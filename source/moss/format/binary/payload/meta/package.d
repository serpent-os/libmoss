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

module moss.format.binary.payload.meta;

public import moss.format.binary.payload;

/**
 * The currently writing version for MetaPayload
 */
const uint16_t metaPayloadVersion = 1;

/**
 * A MetaPayload provides a simple Key/Value storage mechanism for metadata
 * within a payload blob. Each key is strongly typed to the value and is
 * tagged with a given context *type*, such as "Name", "Summary", etc.
 *
 * The MetaPayload, when populated, contains all useful information on a
 * package, as seen from the package manager.
 */
final class MetaPayload : Payload
{

public:

    /**
     * Each implementation must call the base constructor to ensure that
     * the PayloadType property has been correctly set.
     */
    this() @safe
    {
        super(PayloadType.Meta, metaPayloadVersion);
    }

    /**
     * We ensure we're registered correctly with the Reader subsystem
     */
    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!MetaPayload(PayloadType.Meta);
    }

    /**
     * Subclasses must implement the decode method so that reading of the
     * stream data is possible.
     */
    override void decode(scope Reader rdr) @safe
    {
        import std.stdio : writeln;

        writeln("MetaPayload.decode(): IMPLEMENT ME");
    }

    /**
     * Subclasses must implement the encode method so that writing of the
     * stream data is possible.
     */
    override void encode(scope WriterToken* wr) @safe
    {
        import std.stdio : writeln;

        writeln("MetaPayload.encode(): IMPLEMENT ME");
    }
}
