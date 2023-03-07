/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.binary.repo.repo_writer
 *
 * Defines the notion of a RepoWriter, which is responsible for emitting
 * a binary moss index repository to disk.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.binary.repo.repo_writer;

import moss.format.binary.reader;
import moss.format.binary.writer;
import moss.format.binary : mossFormatVersionNumber;
import moss.format.binary.payload.meta;
import moss.core : computeSHA256;
import std.experimental.logger;
import std.string : format;

/**
 * A RepoWriter is responsible for emitting a binary repository to disk.
 * It is not responsible for the management of individual assets on disk,
 * simply for recording a MetaPayload with some attributes in a sequential
 * index.
 *
 * More advanced repo formats will arrive later.
 */
public final class RepoWriter
{
    /**
     * Construct a new RepoWriter
     */
    this(const(string) outputDir) @safe
    {
        import std.array : join;

        _outputDir = outputDir;
        _indexFile = join([_outputDir, "stone.index"], "/");
        archWriter = new Writer(File(_indexFile, "wb"), mossFormatVersionNumber);
        archWriter.fileType = MossFileType.Repository;
        archWriter.compressionType = PayloadCompression.Zstd;
    }

    /**
     * Close the repository index emission
     */
    void close()
    {
        archWriter.close();
    }

    /**
     * Return the output directory for the RepoWriter
     */
    pure @property const(string) outputDir() @safe @nogc nothrow
    {
        return _outputDir;
    }

    /**
     * Add a package to the index
     */
    void addPackage(const(string) inpPath, const(string) packageURI)
    {
        import std.exception : enforce;

        auto fi = File(inpPath, "rb");
        auto reader = new Reader(fi);

        scope (exit)
        {
            reader.close();
        }

        if (reader.fileType != MossFileType.Binary)
        {
            info(format!"Skipping non binary file: %s"(reader.fileType));
        }

        auto metaPayload = reader.payload!MetaPayload();
        enforce(metaPayload !is null, "RepoWriter.addPackage(): Unable to grab MetaPayload");
        metaPayload.addRecord(RecordType.String, RecordTag.PackageURI, packageURI);
        auto fiSize = fi.size();
        metaPayload.addRecord(RecordType.Uint64, RecordTag.PackageSize, fiSize);
        auto hash = computeSHA256(inpPath, fiSize > 16 * 1024 * 1024);
        metaPayload.addRecord(RecordType.String, RecordTag.PackageHash, hash);
        archWriter.addPayload(metaPayload);
    }

private:

    string _outputDir = null;
    string _indexFile = null;
    Writer archWriter = null;
}
