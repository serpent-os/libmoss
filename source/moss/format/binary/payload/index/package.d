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

module moss.format.binary.payload.index;

public import moss.format.binary.payload;

/**
 * The currently writing version for IndexPayload
 */
const uint16_t indexPayloadVersion = 1;

/**
 * An IndexPayload contains a set of offsets to unique files contained within
 * a ContentPayload, and can be viewed akin to a lookup table. Each file is
 * stored in sequence without padding, thus an offset lookup helps to split
 * a singular blob into several files again.
 */
final class IndexPayload : Payload
{

public:

    /**
     * Create a new instance of IndexPayload
     */
    this() @safe
    {
        super(PayloadType.Index, indexPayloadVersion);
    }

    /**
     * We ensure we're registered correctly with the Reader subsystem
     */
    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!IndexPayload(PayloadType.Index);
    }

    /**
     * Encode the IndexPayload to the WriterToken
     */
    override void encode(scope WriterToken* wr) @trusted
    {
        import std.stdio : writeln;

        writeln("IndexPayload.encode(): Implement me");
    }

    /**
     * Decode the IndexPayload from the ReaderToken
     */
    override void decode(scope ReaderToken* rdr) @trusted
    {
        import std.stdio : writeln;

        writeln("IndexPayload.decode(): Implement me");
    }
}
