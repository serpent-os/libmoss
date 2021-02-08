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
public import moss.format.binary.payload;
public import moss.format.binary.header;

import moss.format.binary.endianness;

/**
 * Encapsulates the underlying Payload so we can provide some tracking
 * and iteration abiliies
 */
struct PayloadWrapper
{
    /** Extend Payload with PayloadWrapper functionality */
    Payload pt;
    alias pt this;

package:

    /**
     * Returns the 'read' property, i.e. was we decoded or not
     */
    pure @property bool read() @safe @nogc nothrow
    {
        return _read;
    }

    /**
     * Update the read property
     */
    pure @property void read(bool b) @safe @nogc nothrow
    {
        _read = b;
    }

private:

    bool _read = false;
}

/**
 * The Reader is a low-level mechanism for parsing Moss binary packages.
 */
final class Reader
{

private:

    File _file;
    Header _header;
    int16_t payloadIndex = -1;
    int16_t requestedIndex = 0;
    PayloadWrapper curPayload;

    /**
     * Load the current payload
     */
    Payload loadPayload() @trusted
    {
        import std.stdio : fread;
        import std.exception : enforce;

        scope auto fp = _file.getFP();

        Payload ret;
        enforce(fread(&ret, Payload.sizeof, 1, fp) == 1, "nextPayload(): Failed to read");
        ret.toHostOrder();

        return ret;
    }

    /**
     * Skip the contents of the payload completely
     */
    void skipPayload() @trusted
    {
        import std.stdio : fseek, SEEK_CUR;

        _file.seek(curPayload.length, SEEK_CUR);
    }

public:
    @disable this();

    /**
     * Construct a new Reader for the given filename
     */
    this(File file) @trusted
    {
        import std.exception : enforce;
        import std.stdio : fread;

        scope auto fp = file.getFP();

        _file = file;

        auto size = _file.size;
        enforce(size != 0, "Reader(): empty file");
        enforce(size > Header.sizeof, "Reader(): File too small");
        enforce(fread(&_header, Header.sizeof, 1, fp) == 1, "Reader(): Failed to read Header");

        _header.toHostOrder();
        _header.validate();

        curPayload = PayloadWrapper();
    }

    ~this() @safe
    {
        close();
    }

    /**
     * Return the current entry in the reader
     */
    @property PayloadWrapper front()
    {
        if (requestedIndex != payloadIndex)
        {
            if (requestedIndex > 0 && !curPayload.read)
            {
                skipPayload();
            }
            curPayload.pt = loadPayload();
            payloadIndex = requestedIndex;
        }
        return curPayload;
    }

    /**
     * Return true if there are no more entries
     */
    @property bool empty()
    {
        return requestedIndex >= _header.numPayloads;
    }

    /**
     * Pop the current entry and find the next
     */
    @property PayloadWrapper popFront()
    {
        ++requestedIndex;
        return curPayload;
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
}
