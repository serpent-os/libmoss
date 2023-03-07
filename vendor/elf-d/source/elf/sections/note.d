//          Copyright Serpent OS Developers 2021.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

/**
 * Parse and make available the contents of an ELFNote section
 * (such as .gnu.note.build-id)
 *
 * .gnu.note.build-id contains a hash that can be used to identify to which
 * library a split-debug .so file belongs.
 */

module elf.sections.note;

import std.exception;
import std.stdint : uint32_t;
import std.string : fromStringz;

import elf, elf.low;

static if (__VERSION__ >= 2079)
	alias elfEnforce = enforce!ELFException;
else
	alias elfEnforce = enforceEx!ELFException;

/**
 * Parse an ELFNote (format is identical between 32 and 64 bit)
 */
struct ElfNote
{
    /* slice for performance */
    private char[] _name;
    /** ELFNote descriptor (= contents, interpretation varies with type) */
    ubyte[] descriptor;
    /** ELFNote type (NT_GNU_BUILD_ID = 3) */
    uint32_t type;

    /**
     * Construct a new ELF Note from the given section (should start with .note)
     */
    this(ELFSection section)
    {
        auto contents = section.contents;

        /* we need a valid note (length) */
        elfEnforce(contents.length > ELFNoteHeaderL.sizeof, "Invalid ElfNote header size!");
        auto hdr = cast(ELFNoteHeaderL*) contents[0 .. ELFNoteHeaderL.sizeof];
        /* this is an integer corresponding to note types */
        this.type = hdr.noteType;

        elfEnforce(hdr.noteNameSize > 0, "Invalid ElfNote noteNameSize!");
        elfEnforce(hdr.noteDescriptorSize > 0, "Invalid ElfNote noteDescriptorSize!");
        elfEnforce(contents.length == ELFNoteHeaderL.sizeof + hdr.noteNameSize + hdr.noteDescriptorSize,
            "Invalid ElfNote content size!");

        /* we need to parse the noteName */
        this._name = cast(char[]) contents[ELFNoteHeaderL.sizeof .. ELFNoteHeaderL.sizeof + hdr.noteNameSize];
        /* ... and the noteDescriptor (= contents of the note) */
        this.descriptor = contents[ELFNoteHeaderL.sizeof + hdr.noteNameSize .. $];
    }

    /** Name of the note as a string */
    @property auto name()
    {
        return cast(string) fromStringz(_name.ptr);
    }
}
