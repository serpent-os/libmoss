//        Copyright © Serpent OS Developers 2021-23.
//    Includes example code Copyright © Yazan Dabain 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

/**
 * Example application showing how to use the various elf-d APIs.
 */

import std.algorithm;
import std.array;
import std.exception;
import std.file;
import std.format : format;
import std.path : baseName;
import std.range : InputRange, only, walkLength;
import std.stdio : writefln, writeln;
import std.string : strip;
import std.typecons : Nullable;

import elf, elf.low, elf.low32, elf.low64, elf.meta, elf.sections, elf.sections.dynamiclinkingtable;

static if (__VERSION__ >= 2079)
	alias elfEnforce = enforce!ELFException;
else
	alias elfEnforce = enforceEx!ELFException;


void main(string[] args) {
	// Do we have other arguments than the name of the present file (args[0])?
	if (args.length > 1) {
		// writeln("args: ", args);
		// we're not interested in the present file (args[0])
		foreach (a; args[1 .. $]) {
			// writeln("=== Checking for ELF data in ", a, " ...");
			listElfFiles(a);
		}
	} else {
		// writeln("=== Defaulting to checking for ELF data in /usr/lib/libc.so.6 ...");
		// listElfFiles("/usr/lib/libc.so.6");
		writefln!"Usage: ./%s \"file-or-path-to-recursively-check-for-ELF-contents\" [path path ...]"( baseName(args[0]));
		return;
	}
}


/**
 * Match any regular files in path which appear to be ELF files
 */
void listElfFiles(const(string) path) {
	auto sPath = path.strip();
	//writeln("listElfFiles( ", sPath, " );");
	try {
		if (sPath.isFile) {
			_parseElfFile(DirEntry(sPath));
		}
		if (sPath.isDir) {
			/* false means to not follow symlinks -- less chance to get in endless loops */
			foreach (f; dirEntries(sPath, SpanMode.breadth, false)) {
				if (f.isFile) {
					_parseElfFile(f);
				}
			}
		}
	} catch (FileException ex) {
		// writeln("Shit happens, exiting."); // Handle error
		// writeln(ex);
	}
}


private void _parseElfFile(DirEntry f) {
	try { // if we've made it here, it's a genuine file
		ELF elf = ELF.fromFile(f.name);
		/* These are informational functions inherited from the elf-d example app.d */
		//printHeaderInfo(elf);
		//printSectionNames(elf);
		//printSectionInfo(elf);
		//printSymbolTables(elf);

		/* Show build-id (used for naming debug packages when we split and strip symbols) */
		immutable string buildId = printBuildId(elf, f.name);

		/* Show link-time dependencies per dynamic shared object */
		string soname = printDynamicLinkingSection(elf, f.name);

		/* Show exported (= defined) symbols (functions/variables) */
		printDefinedSymbols(elf, soname);

		/* Show undefined symbols (functions/variables) depended on and imported at link-time */
		printUndefinedSymbols(elf, soname);
	} catch (Exception ex) {
		writeln("Not an ELF file: ", f.name);
		// writeln(ex);
	}
}

/**
 * Print .note.gnu.build-id section if it exists (it should).
 *
 * If the section doesn't exist, we can't name split-out debug files properly.
 */
string printBuildId(ELF elf, const(string) pathname) {
	string buildId = "N/A";
	Nullable!ELFSection nes = elf.getSection(".note.gnu.build-id");
	if (!nes.isNull) {
		try {
			ELFSection es = nes.get;
			if (es.type == SectionType.note) {
				static immutable uint NT_GNU_BUILD_ID = 3;
				/* ASCII hex string for "GNU\0" */
				static immutable auto GNU = [71,   78,   85, 0];
				/* The compiler is smart enough that it can auto-convert uint sizes to ubyte indices */
				auto noteHeader = *cast(ELFNoteHeaderL*) es.contents[0 .. ELFNoteHeaderL.sizeof];
				const auto noteNameArray = es.contents[
					ELFNoteHeaderL.sizeof .. ELFNoteHeaderL.sizeof + noteHeader.noteNameSize];
				/* While this may look like dark magic, it actually just creates a nice hex-formatted string */
				// const auto noteName = join(noteNameArray.map!(ub => "%02x".format(ub)));
				// writeln("noteName: ", noteName);
				if (noteHeader.noteType == NT_GNU_BUILD_ID && noteHeader.noteNameSize == 4 && noteNameArray == GNU) {
					/* Skip past the noteName (which will always be GNU on Linux) */
					immutable uint descriptorStartIndex = cast(uint) ELFNoteHeaderL.sizeof + noteHeader.noteNameSize;
					/* We _really_ don't want to read past the section end */
					immutable uint descriptorEndIndex = descriptorStartIndex + noteHeader.noteDescriptorSize;
					enforce(descriptorEndIndex == es.contents.length,
						"Read past end of section .note.gnu.build-id.contents()!");
					const auto hashArray = es.contents[descriptorStartIndex .. descriptorEndIndex];
					/* Convert each ubyte to hex format, then concatenate array to single buildId hash string */
					buildId = join(hashArray.map!(ub => "%02x".format(ub)));
				}
			}
		}
		catch(Exception ex) {
			// writeln(ex);
		}
	}
	writeln("\n", baseName(pathname), ":");
	writeln("Build_ID:\n\t", buildId);
	return buildId;
}


/**
 * Print selected Dynamic Linking section contents
 */
string printDynamicLinkingSection(ELF elf, const string filepath) {
	// Maybe insert some kind of check here?
	// What kind of check could be useful?
	string soname = "unknown";
	string section = ".dynamic";
	Nullable!ELFSection nes = elf.getSection(section);
	if (!nes.isNull) {
		ELFSection es = nes.get;
		if (es.type == SectionType.dynamicLinkingTable) {
			/* dt assignment shouldn't fail here */
			auto dt = DynamicLinkingTable(es);
			//writeln("  Current Section name: ", es.name);
			//writeln("  Current Section info: ", es.info);
			//writeln("  Current Section type: ", es.type);
			if (dt.soname == "") {
				soname = baseName(filepath);
			} else {
				soname = dt.soname;
			}
			auto sortedLibs = dt.needed.sort!("a < b");
			writeln("NEEDED_libs:");
			foreach (lib; sortedLibs) {
				writefln!"\t%s"(lib);
			}
			//writeln("  Current Section contents:\n", es.contents);
		}
	} else {
		writeln("No section '", section, "' found?");
	}
	return soname;
}


/**
 * Print a tab-prefixed, newline delimited list of exported ELF symbols
 */
void printDefinedSymbols(ELF elf, string name) {
	writeln("ABI_exports:");
	// the .symtab section contains (non-allocable) full symbol table for
	// use during build time linking and for debugging at runtime.
	// It is often stripped as it is mostly relevant for build time linking
	// and debugging purposes
	foreach (section; only(".symtab", ".dynsym")) {
		writeln("\t#", section, " section:");
		Nullable!ELFSection nes = elf.getSection(section);
		if (!nes.isNull) {
			try {
				ELFSection es = nes.get;
				auto symbolTable = SymbolTable(es).symbols();
				/* a section index of 0 means that the symbol is undefined */
				auto definedSymbols = symbolTable.filter!(
					sym => sym.sectionIndex != 0
					&& sym.name != ""
					&& sym.binding == SymbolBinding.global
					&& (sym.type == SymbolType.func || sym.type == SymbolType.object));
				auto sortedDefinedSymbolNames = definedSymbols.map!(
					sym => format!"%s"(sym.name))
					/* .array implements RandomAccessRange interface needed for sort */
					.array.sort();
				foreach (sym; sortedDefinedSymbolNames) {
					writefln!"\t%s"(sym);
				}
			} catch (Exception ex) {
				writeln("'- caught an exception in ", __FILE__, ":L", __LINE__);
				//writeln(ex);
				// FIXME: should probably log the error?
			}
		} else {
			writeln("\t (no such ELF section in ", name, ")");
		}
	}
}

/**
 * Attempt to print undefined symbols and their corresponding DT_NEEDED entry
 *
 * Undefined symbols are the symbols that need to be loaded from other ELF shared
 * objects at runtime.
 */
void printUndefinedSymbols(ELF elf, string name) {
	writeln("ABI_imports:");
	// .symtab section has symbol versioning applied when looking at .name properties
	// while .dynsym does not.
	foreach (section; only(".symtab", ".dynsym",))
	{
		writeln("\t#", section, " section:");
		Nullable!ELFSection nes = elf.getSection(section);
		if (!nes.isNull) {
			try {
				ELFSection es = nes.get;
				auto symbolTable = SymbolTable(es).symbols();
				/* a section index of 0 means that the symbol is undefined */
				auto undefinedSymbols = symbolTable.filter!(
					sym => sym.sectionIndex == 0
					&& sym.name != ""
					&& sym.binding == SymbolBinding.global
					&& (sym.type == SymbolType.func || sym.type == SymbolType.object));
				auto sortedUndefinedSymbols = undefinedSymbols.map!(
					sym => format!"%s"(sym.name))
					/* .array implements RandomAccessRange interface needed for sort */
					.array.sort();
				foreach (sym; sortedUndefinedSymbols)
				{
					writefln!"\t%s"(sym);
				}
			} catch (Exception ex) {
				writeln("'- caught an exception in ", __FILE__, ":L", __LINE__);
				//writeln(ex);
				// FIXME: should probably log the error?
			}
		} else {
			writeln("\t (no such ELF section in ", name, ")");
		}
	}
}

/**
 * Print ELF header info
 */
void printHeaderInfo(ELF elf) {
	writeln();
	writeln("ELF file properties:");

	// ELF file general properties
	writeln("  fileClass: ", elf.header.identifier.fileClass);
	writeln("  dataEncoding: ", elf.header.identifier.dataEncoding);
	writeln("  abiVersion: ", elf.header.identifier.abiVersion);
	writeln("  osABI: ", elf.header.identifier.osABI);
	writeln("  objectFileType: ", elf.header.objectFileType);
	writeln("  machineISA: ", elf.header.machineISA);
	writeln("  version_: ", elf.header.version_);
	writefln!"  entryPoint: 0x%x"(elf.header.entryPoint);
	writeln("  programHeaderOffset: ", elf.header.programHeaderOffset);
	writeln("  sectionHeaderOffset: ", elf.header.sectionHeaderOffset);
	writeln("  sizeOfProgramHeaderEntry: ", elf.header.sizeOfProgramHeaderEntry);
	writeln("  numberOfProgramHeaderEntries: ", elf.header.numberOfProgramHeaderEntries);
	writeln("  sizeOfSectionHeaderEntry: ", elf.header.sizeOfSectionHeaderEntry);
	writeln("  numberOfSectionHeaderEntries: ", elf.header.numberOfSectionHeaderEntries);
}

/**
 * Print info about each ELF section
 */
void printSectionInfo(ELF elf) {
	writeln();
	writeln("Sections:");

	// ELF sections
	foreach (section; elf.sections) {
		writeln("  Section (", section.name, ")");
		writefln!"    type: %s"(section.type);
		writefln!"    address: 0x%x"(section.address);
		writefln!"    offset: 0x%x"(section.offset);
		writefln!"    flags: 0x%08b"(section.flags);
		writefln!"    size: %s bytes"(section.size);
		writefln!"    entry size: %s bytes"(section.entrySize);
		writeln();
	}
}

/**
 * Print the ELF section names
 */
void printSectionNames(ELF elf) {
	import elf.low : SectionType;

	foreach (section; elf.sections) {
		if (section.type !is SectionType.null_) {
			writeln("\t", section.name, "(type: ", section.type, ")");
		}
	}
}

/**
 * Print a list of symbol table sections for ELF file
 */
void printSymbolTables(ELF elf) {
	writeln("\nSymbol table sections contents:");

	foreach (section; only(".symtab", ".dynsym",)) {
		Nullable!ELFSection nes = elf.getSection(section);
		if (!nes.isNull) {
			ELFSection es = nes.get;
			writeln("  Symbol table ", section, " contains: ", SymbolTable(es).symbols().walkLength());

			writefln("%-(    %s\n%)", SymbolTable(es).symbols()
					.map!(es => format!"%s\t%s\t%s\t(%s)"(es.binding, es.type, es.name, es.sectionIndex)));
			writeln();
		}
	}
}

/**
 * Check a file.attribute permission mask for whether any executable bits are set
 */
bool isExecutable(const(uint) permissionBits) pure @nogc nothrow @safe {
	// pick out the executable bits = 0000_0000_0100_1001 = 0x0409
	//                           u   g   o
	//                          rwx rwx rwx
	immutable uint exeMask = 0b_001_001_001;
	// if any of the relevant bits are set, the result will be > 0 and thus true
	const uint result = permissionBits & exeMask;
	// writefln("%0b", result);
	return result > 0;
}
