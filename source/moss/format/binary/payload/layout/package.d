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

module moss.format.binary.payload.layout;

public import moss.format.binary.payload;

/**
 * The currently writing version for LayoutPayload
 */
const uint16_t layoutPayloadVersion = 1;

/**
 * A LayoutPayload contains a series of definintions on how to apply a particular
 * filesystem layout for a given package to the target filesystem. It is used
 * in conjunction with the cache assets stored and referenced within ContentPayload
 * and IndexPayload as the final step of making package assets available.
 */
final class LayoutPayload : Payload
{

public:

    /**
     * Create a new instance of LayoutPayload
     */
    this() @safe
    {
        super(PayloadType.Layout, layoutPayloadVersion);
    }

    /**
     * We ensure we're registered correctly with the Reader subsystem
     */
    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!LayoutPayload(PayloadType.Layout);
    }

    /**
     * Encode the LayoutPayload to the WriterToken
     */
    override void encode(scope WriterToken* wr) @trusted
    {
        import std.stdio : writeln;

        writeln("LayoutPayload.encode(): Implement me");
    }

    /**
     * Decode the LayoutPayload from the ReaderToken
     */
    override void decode(scope ReaderToken* rdr) @trusted
    {
        import std.stdio : writeln;

        writeln("LayoutPayload.decode(): Implement me");
    }
}
