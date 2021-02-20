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

module moss.format.binary.writer.token;

import core.stdc.stdio : FILE;
import std.digest.crc : CRC64ISO;

import moss.format.binary.payload.header;

/**
 * A WriterToken instance is passed to each Payload as a way for them
 * to safely encode data to the Archive.
 */
public struct WriterToken
{

    /**
     * Merge data into our underlying buffer
     */
    pragma(inline, true) void appendData(ref ubyte[] data)
    {
        rawData ~= data;
        hash.put(data);
    }

    /**
     * Copy data to buffer without reference
     */
    pragma(inline, true) void appendData(ubyte[] data)
    {
        rawData ~= data;
        hash.put(data);
    }

    /**
     * Copy single byte to buffer
     */
    pragma(inline, true) void appendData(ubyte d)
    {
        rawData ~= d;
        hash.put(d);
    }

    /**
     * Flush the underlying data into the original output file
     * This will calculate the CRC automatically as well as
     * perform required compression.
     */
    void flush(scope PayloadHeader* pHdr, scope FILE* fp) @system
    {
        import core.stdc.stdio : fwrite;
        import std.exception : enforce;

        /* Handle empty payload cases */
        if (rawData is null || rawData.length < 1)
        {
            pHdr.plainSize = 0;
            pHdr.storedSize = 0;
            pHdr.compression = PayloadCompression.None;
            pHdr.encode(fp);
            return;
        }

        /* Set PayloadHeader internal fields to match data */
        pHdr.plainSize = rawData.length;
        pHdr.storedSize = pHdr.plainSize;
        pHdr.crc64 = hash.finish();

        /* TODO: Add automatic "best" compression based on segment size */
        pHdr.compression = PayloadCompression.Zstd;

        /**
         * Now handle compression of the entire payload
         */
        final switch (pHdr.compression)
        {
        case PayloadCompression.Zstd:
            /* zstd compresion of payload */
            import zstd : compress;

            ubyte[] comp = compress(rawData, 16);
            pHdr.storedSize = comp.length;

            /* Emission */
            pHdr.encode(fp);
            enforce(fwrite(comp.ptr, ubyte.sizeof, comp.length,
                    fp) == comp.length, "WriterToken.flush(): Failed to write data");
            break;
        case PayloadCompression.Zlib:
            /* zlib compression of payload */
            import std.zlib : compress;

            ubyte[] comp = compress(rawData, 6);
            pHdr.storedSize = comp.length;

            /* Emission */
            pHdr.encode(fp);
            enforce(fwrite(comp.ptr, ubyte.sizeof, comp.length,
                    fp) == comp.length, "WriterToken.flush(): Failed to write data");
            break;
        case PayloadCompression.None:
        case PayloadCompression.Unknown:
            /* Disabled compression */
            pHdr.compression = PayloadCompression.None;
            pHdr.encode(fp);
            enforce(fwrite(rawData.ptr, ubyte.sizeof, rawData.length,
                    fp) == rawData.length, "WriterToken.flush(): Failed to write data");
            break;
        }
    }

private:
    ubyte[] rawData;
    CRC64ISO hash;
}
