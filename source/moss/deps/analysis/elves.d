/*
 * This file is part of moss-deps.
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

module moss.deps.analysis.elves;

public import moss.deps.query.dependency;
public import moss.deps.analysis.chain;

/**
 * Used to match the first 4 bytes of files
 */
static private immutable ubyte[4] elfMagic = [0x7f, 0x45, 0x4c, 0x46];

/**
 * This function will return "NextFunction" if the input file is a valid ELF
 * file. Otherwise, it will simply return "NextHandler".
 */
public AnalysisReturn acceptElfFiles(scope Analyser analyser, in FileInfo fileInfo)
{
    import std.stdio : File;

    if (fileInfo.type != FileType.Regular)
    {
        return AnalysisReturn.NextHandler;
    }

    auto fi = File(fileInfo.fullPath, "rb");
    scope (exit)
    {
        fi.close();
    }
    /* Need at least a 16-byte file */
    if (fi.size() < 16)
    {
        return AnalysisReturn.NextHandler;
    }

    /* Check the magic */
    ubyte[4] elfBuffer = [0, 0, 0, 0];
    const auto firstBytes = fi.rawRead(elfBuffer);
    if (firstBytes != elfMagic)
    {
        return AnalysisReturn.NextHandler;
    }

    /* Eligible */
    return AnalysisReturn.NextFunction;
}

/**
 * Assuming the input is a valid ELF file, i.e. from using acceptElfFiles, we
 * can scan the binary for any dependencies (DT_NEEDED) and provided SONAME.
 */
public AnalysisReturn scanElfFiles(scope Analyser analyser, in FileInfo fileInfo)
{
    import elf : ELF, DynamicLinkingTable;
    import std.string : format;
    import std.string : fromStringz;
    import std.algorithm : each;

    auto fi = ELF.fromFile(fileInfo.fullPath);
    foreach (section; fi.sections)
    {
        switch (section.name)
        {
        case ".interp":
            /* Extract DT_INTERP, program interpreter */
            auto dtInterp = cast(char[]) section.contents;
            auto dtInterpSz = fromStringz(dtInterp.ptr);
            auto d = Dependency("%s(%s)".format(dtInterpSz,
                    fi.header.machineISA), DependencyType.Interpeter);
            analyser.bucket(fileInfo).addDependency(d);
            break;
        case ".dynamic":
            /* Extract DT_NEEDED, shared library dependencies */
            DynamicLinkingTable(section).needed.each!((r) => {
                auto dtNeeded = "%s(%s)".format(r, fi.header.machineISA);
                auto d = Dependency(dtNeeded, DependencyType.SharedLibraryName);
                analyser.bucket(fileInfo).addDependency(d);
            }());
            break;
        default:
            break;
        }
    }
    return AnalysisReturn.NextFunction;
}

unittest
{
    import std.file : thisExePath;
    import moss.deps.analysis.analyser : Analyser;

    auto ourname = thisExePath;

    auto fi = FileInfo(ourname, ourname);
    auto rule = AnalysisChain("elves", [
            &acceptElfFiles, &scanElfFiles, &includeFile
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
