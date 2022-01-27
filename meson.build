project(
	'moss-format',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

dep_libzstd = dependency('libzstd', version: '>= 1.5.0')
dep_xxhash = dependency('libxxhash', version: '>= 0.8.1')

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

# Grab moss-core
moss_core = subproject('moss-core')
link_libcore = moss_core.get_variable('link_libcore')

formatSource_sources = [
    'source/moss/format/source/package.d',
    'source/moss/format/source/package_definition.d',
    'source/moss/format/source/schema.d',
    'source/moss/format/source/source_definition.d',
    'source/moss/format/source/tuning_flag.d',
    'source/moss/format/source/tuning_group.d',
    'source/moss/format/source/yml_helper.d',
    'source/moss/format/source/macros.d',
    'source/moss/format/source/spec.d',
    'source/moss/format/source/build_definition.d',
    'source/moss/format/source/build_options.d',
    'source/moss/format/source/upstream_definition.d',
    'source/moss/format/source/script.d',
]

formatBinary_sources = [
    'source/moss/format/binary/archive_header.d',
    'source/moss/format/binary/endianness.d',
    'source/moss/format/binary/package.d',
    'source/moss/format/binary/payload/content/package.d',
    'source/moss/format/binary/payload/header.d',
    'source/moss/format/binary/payload/index/entry.d',
    'source/moss/format/binary/payload/index/package.d',
    'source/moss/format/binary/payload/kvpair/package.d',
    'source/moss/format/binary/payload/layout/entry.d',
    'source/moss/format/binary/payload/layout/entryset.d',
    'source/moss/format/binary/payload/layout/package.d',
    'source/moss/format/binary/payload/meta/record.d',
    'source/moss/format/binary/payload/meta/package.d',
    'source/moss/format/binary/payload/meta/record_pair.d',
    'source/moss/format/binary/payload/package.d',
    'source/moss/format/binary/reader/zstd_token.d',
    'source/moss/format/binary/reader/package.d',
    'source/moss/format/binary/reader/token.d',
    'source/moss/format/binary/writer/zlib_token.d',
    'source/moss/format/binary/writer/zstd_token.d',
    'source/moss/format/binary/writer/package.d',
    'source/moss/format/binary/writer/token.d',
    'source/moss/format/binary/repo/package.d',
    'source/moss/format/binary/repo/repo_writer.d',
]

libmoss_format_source_includes = [
    include_directories('source'),
    include_directories('external/dyaml/source'),
    include_directories('external/tinyendian/source'),
]

libmoss_format_source = static_library(
	'moss-format-source',
	formatSource_sources,
	install: installFiles,
    dependencies: [link_libcore],
	include_directories: libmoss_format_source_includes,
)

link_libmoss_format_source = declare_dependency(
	link_with: libmoss_format_source,
	include_directories: libmoss_format_source_includes,
)

libmoss_format_binary_includes = [
    include_directories('source'),
    include_directories('external/xxhash-d/source'),
    include_directories('external/zstd/source'),
]

libmoss_format_binary = static_library(
	'moss-format-binary',
	formatBinary_sources,
	install: installFiles,
    dependencies: [link_libcore, dep_xxhash, dep_libzstd],
	include_directories: libmoss_format_binary_includes,
)

link_libmoss_format_binary = declare_dependency(
	link_with: libmoss_format_binary,
	include_directories: libmoss_format_binary_includes,
)

# Installed system-wide?
if installFiles
	
	# Install source for other D applications
	install_subdir('source/moss', install_dir: 'include/d/moss-format')

	# Generate pkgconfig for linking
	pkgconf_source = pkgconf.generate(name: 'moss-format-source',
		libraries: libmoss_format_source,
		subdirs: 'd/moss-format',
		version: meson.project_version(),
		description: 'moss-format source module'
	)

	# Generate pkgconfig for linking
	pkgconf_binary = pkgconf.generate(name: 'moss-format-binary',
		libraries: libmoss_format_binary,
		subdirs: 'd/moss-format',
		version: meson.project_version(),
		description: 'moss-format binary module'
	)

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'moss-format',
        requires: [
            'moss-format-source',
            'moss-format-binary',
        ],
		version: meson.project_version(),
		description: 'moss-format binary module'
	)
endif
