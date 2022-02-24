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

module moss.format.binary.repo.repo_writer;

import moss.format.binary.reader;
import moss.format.binary.writer;
import moss.format.binary : mossFormatVersionNumber;
import moss.format.binary.payload.meta;
import moss.core : computeSHA256;

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
        import std.stdio : writeln;

        auto fi = File(inpPath, "rb");
        auto reader = new Reader(fi);

        scope (exit)
        {
            reader.close();
        }

        if (reader.fileType != MossFileType.Binary)
        {
            writeln("Skipping non binary file: ", reader.fileType);
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
