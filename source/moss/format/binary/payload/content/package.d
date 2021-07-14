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

module moss.format.binary.payload.content;

public import moss.format.binary.payload;

/**
 * The currently writing version for ContentPayload
 */
const uint16_t contentPayloadVersion = 1;

package struct ContentEntry
{
    string hash;
    string originPath;
}
/**
 * A ContentPayload is responsible for storing the actual content of a moss
 * archive in a deduplicated fashion. It is only permitted to store unique
 * content, keyed by a unique hash.
 *
 * The key itself is not part of the ContentPayload stream, rather, all files
 * are stored sequentially to permit better global compression. The location
 * of a file within the ContentPayload is referenced by the IndexPayload, which
 * knows exactly where each file lives.
 */
final class ContentPayload : Payload
{

public:

    /**
     * Create a new instance of ContentPayload
     */
    this() @safe
    {
        super(PayloadType.Content, contentPayloadVersion, StorageType.Content);
    }

    /**
     * We ensure we're registered correctly with the Reader subsystem
     */
    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!ContentPayload(PayloadType.Content);
    }

    /**
     * Encode the ContentPayload to the WriterToken
     */
    override void encode(scope WriterToken wr) @trusted
    {
        import std.algorithm : each;

        encoderQueue.each!((e) => encodeOne(e, wr));
    }

    /**
     * Decode the IndexPayload from the ReaderToken
     */
    override void decode(scope ReaderToken rdr) @trusted
    {
        import std.stdio : writeln;

        writeln("ContentPayload.decode(): Implement me");
    }

    /**
     * Enqueue a file for processing/encoding
     */
    void addFile(const(string) id, const(string) path) @trusted
    {
        ContentEntry queueable;
        queueable.hash = id;
        queueable.originPath = path;
        encoderQueue ~= queueable;

        recordCount = cast(uint32_t) encoderQueue.length;
    }

    /**
     * Encode a single file to the stream
     */
    void encodeOne(ref ContentEntry entry, scope WriterToken wr) @trusted
    {
        import std.stdio : File;

        File fi = File(entry.originPath, "rb");
        foreach (ubyte[] buffer; fi.byChunk(128 * 1024))
        {
            wr.appendData(buffer);
        }
    }

private:

    ContentEntry[] encoderQueue;
}
