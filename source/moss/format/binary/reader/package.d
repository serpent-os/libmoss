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
 * The Reader is a low-level mechanism for parsing Moss binary packages.
 */
final class Reader
{

private:

    File _file;
    ArchiveHeader _header;

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
        return null;
    }

    /**
     * The headers property returns a copy of the headers as found in the stream,
     * sequentially.
     */
    @property PayloadHeader[] headers() @safe nothrow
    {
        return null;
    }
}
