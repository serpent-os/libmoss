/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.payload.content
 *
 * Defines the notion of a binary ContentPayload w/deduplication.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.payload.content;

public import moss.format.binary.payload;
import std.experimental.logger;

/**
 * The currently writing version for ContentPayload
 */
const uint16_t contentPayloadVersion = 1;

package struct ContentEntry
{
    ubyte[16] digest;
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

        encoderQueue.each!((e) => wr.appendFile(e.originPath));
    }

    /**
     * Decode the IndexPayload from the ReaderToken
     */
    override void decode(scope ReaderToken rdr) @trusted
    {
        error("ContentPayload.decode(): Implement me");
    }

    /**
     * Enqueue a file for processing/encoding
     */
    void addFile(in ubyte[16] digest, in string path) @trusted
    {
        ContentEntry queueable;
        queueable.digest = digest;
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
