
# moss-format:source

if with_moss_format_source

    formatSource_sources = [
        'source/build_definition.d',
        'source/build_options.d',
        'source/macros.d',
        'source/package.d',
        'source/package_definition.d',
        'source/path_definition.d',
        'source/schema.d',
        'source/script.d',
        'source/source_definition.d',
        'source/spec.d',
        'source/tuning_flag.d',
        'source/tuning_group.d',
        'source/upstream_definition.d',
        'source/yml_helper.d',
    ]

    libmoss_format_source = static_library(
        'moss-format-source',
        formatSource_sources,
        install: false,
        dependencies: [
            link_libmoss_core,
            link_libyaml,
            link_xxhash,
        ],
        include_directories: [root_includedir],
    )

    link_libmoss_format_source = declare_dependency(
        link_whole: libmoss_format_source,
        include_directories: [root_includedir],
        dependencies: [
            link_libmoss_core,
            link_libyaml,
            link_xxhash,
        ]
    )
endif


# moss-format:binary
if with_moss_format_binary
    formatBinary_sources = [
        'binary/archive_header.d',
        'binary/endianness.d',
        'binary/package.d',
        'binary/payload/content/package.d',
        'binary/payload/header.d',
        'binary/payload/index/entry.d',
        'binary/payload/index/package.d',
        'binary/payload/kvpair/package.d',
        'binary/payload/layout/entry.d',
        'binary/payload/layout/entryset.d',
        'binary/payload/layout/package.d',
        'binary/payload/meta/package.d',
        'binary/payload/meta/record.d',
        'binary/payload/meta/record_pair.d',
        'binary/payload/package.d',
        'binary/reader/package.d',
        'binary/reader/token.d',
        'binary/reader/zstd_token.d',
        'binary/repo/package.d',
        'binary/repo/repo_writer.d',
        'binary/writer/package.d',
        'binary/writer/token.d',
        'binary/writer/zstd_token.d',
    ]

    libmoss_format_binary = static_library(
        'moss-format-binary',
        formatBinary_sources,
        install: false,
        dependencies: [
            link_libmoss_core,
            link_xxhash,
            link_zstd,
        ],
        include_directories: [root_includedir],
    )

    link_libmoss_format_binary = declare_dependency(
        link_whole: [libmoss_format_binary],
        dependencies: [
            link_libmoss_core,
            link_xxhash,
            link_zstd,
        ],
        include_directories: [root_includedir],
    )
endif

# Unified dependency
if with_moss_format_binary and with_moss_format_source
    link_libmoss_format = declare_dependency(
        link_whole: [libmoss_format_binary, libmoss_format_source],
        include_directories: [root_includedir],
        dependencies: [
            link_libmoss_core,
            link_libyaml,
            link_xxhash,
            link_zstd,
        ]
    )
endif
