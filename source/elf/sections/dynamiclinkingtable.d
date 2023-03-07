//          Copyright Serpent OS Developers 2021.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

/**
 * Parse and make available the contents of the Dynamic Linking Table
 * ELF section (.dynamic)
 *
 * Among other useful information, this table contains DT_NEEDED entries,
 * which describe the various link-time ELF file dependencies, which each
 * contain undefined symbols; that is, symbols from other ELF files which are
 * linked to/used by this ELF file.
 *
 */

module elf.sections.dynamiclinkingtable;

import std.conv : to;
import std.exception;
import std.stdio : writefln, writeln;
import std.string : format;
import std.typecons : Nullable;

import elf, elf.low, elf.low32, elf.low64, elf.meta, elf.sections.stringtable;

static if (__VERSION__ >= 2079)
	alias elfEnforce = enforce!ELFException;
else
	alias elfEnforce = enforceEx!ELFException;

/**
 * Given a dynamic shared object, parse its .dynamic section
 */
struct DynamicLinkingTable {
	private DynamicLinkingTableImpl m_impl;
	//private StringTable m_strtab;

	/**
	 * Constuct a DynamicLinkingTable from a .dynamic section
	 */
	this(ELFSection section) {
		//writeln("Constructing ELFSection");
		/* check if this is a .dynamic section, otherwise throw ELFException? */
		elfEnforce(section.type == SectionType.dynamicLinkingTable, "Not a .dynamic section?");
		if (section.bits == 32) {
			this.m_impl = new DynamicLinkingTableImpl32(section);
		} else {
			this.m_impl = new DynamicLinkingTableImpl64(section);
		}
	}

	/**
	 * Return the name of the present Shared Object ELF file as set in the DT_SONAME field
	 */
	string soname() {
		// linear search through entries
		//writeln("soname()");
		string soname = "";
		foreach (e; entries) {
			//writeln("soname() loop");
			if (e.knownTag() && e.tag() == DynTag.SONAME) {
				soname = e.toString();
			}
		}
		return soname;
	}

	/**
	 * Return the source shared objects containing undefined symbols referenced in the
	 * present Shared Object ELF file in the DT_NEEDED field(s).
	 */
	string[] needed() {
		string[] needed;
		foreach (e; entries) {
			if (e.knownTag() && e.tag() == DynTag.NEEDED) {
				needed ~= e.toString();
			}
		}
		return needed;
	}

	auto entries() {
		//writeln("Constructing entries()");
		static struct Entries {
			private DynamicLinkingTableImpl m_impl;
			private size_t m_currentIndex = 0;

			@property bool empty() {
				return m_currentIndex >= m_impl.length;
			}

			@property ELFDynEntry front() {
				//writeln("Entries.front()");
				elfEnforce(!empty, "out of bounds exception");
				return m_impl.getDynEntryAt(m_currentIndex);
			}

			void popFront() {
				//writeln("Entries.popFront()");
				elfEnforce(!empty, "out of bounds exception");
				this.m_currentIndex++;
			}

			@property typeof(this) save() {
				//writeln("Entries.save()");
				return this;
			}

			this(DynamicLinkingTableImpl impl) {
				//writeln("Entries.this()");
				this.m_impl = impl;
			}
		}
		//writeln("Constructed static struct Entries");

		return Entries(this.m_impl);
	}
}

/**
 * Polymorphic 32/64 bit ELF Dynamic Linking table interface
 */
private interface DynamicLinkingTableImpl {
	ELFDynEntry getDynEntryAt(size_t index);
	@property ulong length();
}

private class DynamicLinkingTableImpl32 : DynamicLinkingTableImpl {
	private ELFSection32 m_section;

	/**
	 * Ensure correct 32bit word size and section type during construction
	 */
	this(ELFSection section) {
		//writeln("Constructing DynamicLinkingTableImpl32");
		elfEnforce(section.bits == 32);
		elfEnforce(section.type == SectionType.dynamicLinkingTable);
		this(cast(ELFSection32) section);
	}

	/**
	 * Once we have a known good ELFSection32, we can stash it
	 */
	this(ELFSection32 section) {
		this.m_section = section;
	}

	/**
	 * Return the ELFDynEntry(32) (wrapped-up ELFDynEntry32L) corresponding to the index parameter
	 */
	ELFDynEntry getDynEntryAt(size_t index) {
		//writeln("ELFSection32: getDynEntryAt");
		elfEnforce(index * ELFDynEntry32L.sizeof < m_section.size);
		ELFDynEntry32L eDe;
		eDe = *cast(ELFDynEntry32L*) m_section.contents[index * ELFDynEntry32L.sizeof .. (
					index + 1) * ELFDynEntry32L.sizeof].ptr;
		return new ELFDynEntry32(m_section, eDe);
	}

	@property ulong length() {
		return m_section.size / ELFDynEntry32L.sizeof;
	}
}

private class DynamicLinkingTableImpl64 : DynamicLinkingTableImpl {
	private ELFSection64 m_section;

	/**
	 * Ensure correct 64bit word size and section type during construction
	 */
	this(ELFSection section) {
		//writeln("Constructing DynamicLinkingTableImpl64");
		elfEnforce(section.bits == 64);
		elfEnforce(section.type == SectionType.dynamicLinkingTable);
		this(cast(ELFSection64) section);
	}

	/**
	 * Once we have a known good ELFSection64, we can stash it
	 */
	this(ELFSection64 section) {
		this.m_section = section;
	}

	/**
	 * Return the ELFDynEntry(64) (wrapped-up ELFDynEntry64L) corresponding to the index parameter
	 */
	ELFDynEntry getDynEntryAt(size_t index) {
		//writeln("DynamicLinkingTableImpl64.getDynEntryAt");
		elfEnforce(index * ELFDynEntry64L.sizeof < m_section.size);
		ELFDynEntry64L eDe;
		eDe = *cast(ELFDynEntry64L*) m_section.contents[index * ELFDynEntry64L.sizeof .. (
					index + 1) * ELFDynEntry64L.sizeof].ptr;
		return new ELFDynEntry64(m_section, eDe);
	}

	@property ulong length() {
		//writeln("DynamicLinkingTableImpl64.length()");
		return m_section.size / ELFDynEntry64L.sizeof;
	}
}

/**
 * Common functionality for ELFDynSection
 */
abstract class ELFDynEntry {
	private ELFSection m_section;

	/* these member functions are all expected to return native machine word size values */
	DynTag tag();
	bool knownTag();
	size_t content(); // generic return value

	//@property:
	//@ReadFrom("tag")
}

/**
 * Wrap up a low-level ELFDynEntry32L data type
 */
final class ELFDynEntry32 : ELFDynEntry {
	private ELFDynEntry32L m_entry;
	private bool m_known_tag;
	private uint m_content;
	private string m_string;

	/**
	 * Construct a 32bit Dynamic Entry
	 */
	this(ELFSection32 section, ELFDynEntry32L entry) {
		//writeln("Constructing ELFDynEntry32");
		this.m_section = section;
		this.m_entry = entry;

		switch (entry.dTag) {
		case DynTag.NEEDED:
		case DynTag.SONAME:
			this.m_known_tag = true;
			this.m_content = cast(ELF32_Word) entry.content; // index type
			StringTable strtab = StringTable(m_section.m_elf.sections[m_section.link()]);
			this.m_string = strtab.getStringAt(this.m_content);
			//this.m_string = format("%s (.strtab index)", this.m_content);
			break;

		default:
			this.m_known_tag = false;
			this.m_content = entry.content;
			this.m_string = format("%s (unknown tag '%d')", this.m_content, entry.dTag);
			break;
		}
	}

	/**
	 * Useful when needing to match on tag
	 */
	override DynTag tag() {
		return cast(DynTag) m_entry.dTag;
	}

	/**
	 * Useful before querying type of tag
	 */
	override bool knownTag() {
		return this.m_known_tag;
	}

	/**
	 * Generic value which can be re-interpreted
	 */
	override ulong content() {
		return cast(ulong) this.m_content;
	}

	/**
	 * What does this object look like as a string?
	 */
	override string toString() {
		return this.m_string;
	}
}

/**
 * Wrap up a low-level ELFDynEntry64L data type
 */
final class ELFDynEntry64 : ELFDynEntry {
	private ELFDynEntry64L m_entry;
	private bool m_known_tag;
	private ulong m_content;
	private string m_string;

	/**
	 * Construct a 64bit Dynamic Entry
	 */
	this(ELFSection64 section, ELFDynEntry64L entry) {
		//writeln("Constructing ELFDynEntry64");
		this.m_section = section;
		this.m_entry = entry;

		switch (entry.dTag) {
		case DynTag.NEEDED:
		case DynTag.SONAME:
			this.m_known_tag = true;
			this.m_content = cast(ELF64_XWord) entry.content; // index type
			StringTable strtab = StringTable(m_section.m_elf.sections[m_section.link()]);
			this.m_string = strtab.getStringAt(this.m_content);
			// this.m_string = format("%s (.strtab index)", this.m_content);
			break;

		default:
			this.m_known_tag = false;
			this.m_content = entry.content;
			this.m_string = format("%s (unknown tag '%d')", this.m_content, entry.dTag);
			break;
		}
	}

	/**
	 * Useful when needing to match on tag
	 */
	override DynTag tag() {
		return cast(DynTag) m_entry.dTag;
	}

	/**
	 * Useful before querying type of tag
	 */
	override bool knownTag() {
		return this.m_known_tag;
	}

	/**
	 * Generic value which can be re-interpreted
	 */
	override ulong content() {
		return this.m_content;
	}

	/**
	 * What does this object look like as a string?
	 */
	override string toString() {
		return this.m_string;
	}
}

/* Dynamic Tag cases:
   - NULL (section end)
   - String table offset (DT_NEEDED and DT_SONAME)
   - Address of
   - Size in bytes
   - Boolean (DT_BIND_NOW, DT_SYMBOLIC, DT_TEXTREL)
 */
