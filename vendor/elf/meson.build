### elf-d

libmoss_vendor_elf_sources = [
    'elf-d/source/elf/meta.d',
    'elf-d/source/elf/package.d',
    'elf-d/source/elf/sections/debugabbrev/package.d',
    'elf-d/source/elf/sections/debugline/debugline32.d',
    'elf-d/source/elf/sections/debugline/debugline64.d',
    'elf-d/source/elf/sections/debugline/package.d',
    'elf-d/source/elf/sections/stringtable.d',
    'elf-d/source/elf/sections/symboltable.d',
    'elf-d/source/elf/sections/dynamiclinkingtable.d',
    'elf-d/source/elf/sections/note.d',
    'elf-d/source/elf/sections/package.d',
    'elf-d/source/elf/low.d',
    'elf-d/source/elf/low32.d',
    'elf-d/source/elf/low64.d',
]

libmoss_vendor_elf_includes = [
    include_directories('elf-d/source'),
]

libmoss_vendor_elf = static_library(
    'moss-vendor-elf',
    libmoss_vendor_elf_sources,
    install: false,
    include_directories: libmoss_vendor_elf_includes
)

link_libmoss_vendor_elf = declare_dependency(
    link_with: libmoss_vendor_elf,
    include_directories: libmoss_vendor_elf_includes
)