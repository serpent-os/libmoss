# vendor: dyaml + tinyendian + elf-d
if with_moss_config or with_moss_format_source
    libyaml_sources = [
        'tinyendian/source/tinyendian.d',
        'dyaml/source/dyaml/composer.d',
        'dyaml/source/dyaml/constructor.d',
        'dyaml/source/dyaml/dumper.d',
        'dyaml/source/dyaml/emitter.d',
        'dyaml/source/dyaml/encoding.d',
        'dyaml/source/dyaml/escapes.d',
        'dyaml/source/dyaml/event.d',
        'dyaml/source/dyaml/exception.d',
        'dyaml/source/dyaml/linebreak.d',
        'dyaml/source/dyaml/loader.d',
        'dyaml/source/dyaml/node.d',
        'dyaml/source/dyaml/package.d',
        'dyaml/source/dyaml/parser.d',
        'dyaml/source/dyaml/queue.d',
        'dyaml/source/dyaml/reader.d',
        'dyaml/source/dyaml/representer.d',
        'dyaml/source/dyaml/resolver.d',
        'dyaml/source/dyaml/scanner.d',
        'dyaml/source/dyaml/serializer.d',
        'dyaml/source/dyaml/stdsumtype.d',
        'dyaml/source/dyaml/style.d',
        'dyaml/source/dyaml/tagdirective.d',
        'dyaml/source/dyaml/token.d'
    ]

    libyaml_includes = [
        include_directories('tinyendian/source'),
        include_directories('dyaml/source'),
    ]

    libyaml = static_library(
        'dyaml',
        libyaml_sources,
        install: false,
        include_directories: libyaml_includes
    )

    link_libyaml = declare_dependency(
        link_with: libyaml,
        include_directories: libyaml_includes,
    )
endif

### elf-d
if with_moss_deps
    libelf_sources = [
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

    libelf_includes = [
        include_directories('elf-d/source'),
    ]

    libelf = static_library(
        'elf-d',
        libelf_sources,
        install: false,
        include_directories: libelf_includes
    )

    link_libelf = declare_dependency(
        link_with: libelf,
        include_directories: libelf_includes
    )
endif
