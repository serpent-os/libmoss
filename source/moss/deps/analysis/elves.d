/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.analysis.elves
 *
 * Match and Analyse ELF files to determine whether they are executables
 * or libraries. Capture and store their shared library dependencies and
 * exported symbols (ABI).
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.analysis.elves;

import elf : ELF, ELF64, ELFSection, DynamicLinkingTable, ElfNote;
import std.string : format, fromStringz, startsWith;
import std.exception : enforce;
import std.algorithm : each, canFind, count;
import std.path : baseName, dirName;
import std.stdio : stderr, File;
import std.file : exists;

public import moss.deps.dependency;
public import moss.deps.analysis.chain;

import std.stdint : uint32_t;

/**
 * Used to match the first 4 bytes of files
 */
static private immutable ubyte[4] elfMagic = [0x7f, 0x45, 0x4c, 0x46];

/**
 * Store BuildID as string
 */
public const AttributeBuildID = "BuildID";

/**
 * Store bitsize (32 or 64)
 */
public const AttributeBitSize = "BitSize";

private static bool isElfFile(in string fullPath) @trusted
{
    auto fi = File(fullPath, "rb");
    scope (exit)
    {
        fi.close();
    }
    /* Need at least a 16-byte file */
    if (fi.size() < 16)
    {
        return false;
    }

    /* Check the magic */
    ubyte[4] elfBuffer = [0, 0, 0, 0];
    const auto firstBytes = fi.rawRead(elfBuffer);
    if (firstBytes != elfMagic)
    {
        return false;
    }

    /* Legit looks like an ELF file */
    return true;
}

/**
 * This function will return "NextFunction" if the input file is a valid ELF
 * file. Otherwise, it will simply return "NextHandler".
 */
public AnalysisReturn acceptElfFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    import std.string : endsWith;
    import std.algorithm : canFind;

    if (fileInfo.path.endsWith(".debug") && fileInfo.path.canFind("/debug/"))
    {
        return AnalysisReturn.NextHandler;
    }

    if (fileInfo.type == FileType.Regular && isElfFile(fileInfo.fullPath))
    {
        return AnalysisReturn.NextFunction;
    }

    return AnalysisReturn.NextHandler;
}

/**
 * Assuming the input is a valid ELF file, i.e. from using acceptElfFiles, we
 * can scan the binary for any dependencies (DT_NEEDED) and provided SONAME.
 */
public AnalysisReturn scanElfFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    auto fi = ELF.fromFile(fileInfo.fullPath);

    bool has64 = ((cast(ELF64) fi) !is null);
    fileInfo.bitSize = has64 ? 64 : 32;

    foreach (section; fi.sections)
    {
        switch (section.name)
        {
        case ".interp":
            /* Extract DT_INTERP, program interpreter */
            auto dtInterp = cast(char[]) section.contents;
            auto dtInterpSz = fromStringz(dtInterp.ptr);
            auto d = Dependency("%s(%s)".format(dtInterpSz,
                    fi.header.machineISA), DependencyType.Interpreter);
            analyser.bucket(fileInfo).addDependency(d);
            break;
        case ".dynamic":
            /* Extract DT_NEEDED, shared library dependencies */
            auto dynTable = DynamicLinkingTable(section);
            dynTable.needed.each!((r) {
                auto dtNeeded = "%s(%s)".format(r, fi.header.machineISA);
                auto d = Dependency(dtNeeded, DependencyType.SharedLibraryName);
                analyser.bucket(fileInfo).addDependency(d);
            });

            /* Soname exposed? Lets share it. */
            /* TODO: Only expose ACTUAL libraries */
            auto soname = dynTable.soname;
            if (soname == "" || !fileInfo.fullPath.canFind(".so"))
            {
                break;
            }
            auto sonameProvider = "%s(%s)".format(soname, fi.header.machineISA);
            auto p = Provider(sonameProvider, ProviderType.SharedLibraryName);
            analyser.bucket(fileInfo).addProvider(p);

            /* Do we possibly have an Interpeter? This is a .dynamic library .. */
            auto localName = soname.baseName;
            if (localName.startsWith("ld-") && fileInfo.path.count('/') == 3
                    && fileInfo.path.startsWith("/usr/lib"))
            {
                string[] interpPaths = [];

                /* 64-bit file */
                if (has64)
                {
                    interpPaths = [
                        "/usr/lib64/%s(%s)".format(localName, fi.header.machineISA),
                        "/lib64/%s(%s)".format(localName, fi.header.machineISA),
                        "/lib/%s(%s)".format(localName, fi.header.machineISA),
                        "%s(%s)".format(fileInfo.path, fi.header.machineISA)
                    ];
                }
                else
                {
                    interpPaths = [
                        "/usr/lib/%s(%s)".format(localName, fi.header.machineISA),
                        "/lib/%s(%s)".format(localName, fi.header.machineISA),
                        "/lib32/%s(%s)".format(localName, fi.header.machineISA),
                        "%s(%s)".format(fileInfo.path, fi.header.machineISA)
                    ];
                }

                /* Add interpreter + soname providers now */
                foreach (pname; interpPaths)
                {
                    auto pInterp = Provider(pname, ProviderType.Interpreter);
                    auto pSoname = Provider(pname, ProviderType.SharedLibraryName);
                    analyser.bucket(fileInfo).addProvider(pInterp);
                    analyser.bucket(fileInfo).addProvider(pSoname);
                }
            }
            break;
        case ".note.gnu.build-id":
            auto note = ElfNote(section);
            import std.digest : toHexString, LetterCase;

            /* Look like a proper build id to us? NT_GNU_BUILD_ID = 3 */
            if (note.type == 3 && note.name == "GNU")
            {
                /* We support XXHASH_3 64 bit (8 bytes) and SHA1 160 bit (20 bytes) Build IDs */
                enforce(note.descriptor.length == 8 || note.descriptor.length == 20);
                fileInfo.buildID = note.descriptor.toHexString!(LetterCase.lower)();
            }
            break;
        default:
            break;
        }
    }
    return AnalysisReturn.NextFunction;
}

/**
 * Specialist handler which will always restat the input file in case it changed
 */
public AnalysisReturn includeElfFiles(scope Analyser analyser, ref FileInfo fileInfo)
{
    fileInfo.update();
    return AnalysisReturn.IncludeFile;
}

unittest
{
    import std.file : thisExePath;
    import moss.deps.analysis.analyser : Analyser;

    auto ourname = thisExePath;

    auto fi = FileInfo(ourname, ourname);
    auto rule = AnalysisChain("elves", [
            &acceptElfFiles, &scanElfFiles, &includeElfFiles
            ]);
    fi.target = "main";
    auto an = new Analyser();
    an.addFile(fi);
    an.addChain(rule);
    an.process();

    import std.stdio : writeln;

    auto deps = an.bucket("main").dependencies;
    assert(!deps.empty, "Cannot find dependenies for this test");
    writeln(deps);
}
