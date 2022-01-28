project(
	'moss-config',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

# Package sources
libmoss_config_sources = [
	'source/moss/config/package.d',
	'source/moss/config/io/package.d',
	'source/moss/config/io/schema.d',
	'source/moss/config/io/snippet.d',
	'source/moss/config/io/configuration.d',
	'source/moss/config/repo.d',
]

aux_config_sources = [
    'external/tinyendian/source/tinyendian.d',
    'external/dyaml/source/dyaml/composer.d',
    'external/dyaml/source/dyaml/constructor.d',
    'external/dyaml/source/dyaml/dumper.d',
    'external/dyaml/source/dyaml/encoding.d',
    'external/dyaml/source/dyaml/escapes.d',
    'external/dyaml/source/dyaml/event.d',
    'external/dyaml/source/dyaml/linebreak.d',
    'external/dyaml/source/dyaml/package.d',
    'external/dyaml/source/dyaml/parser.d',
    'external/dyaml/source/dyaml/queue.d',
    'external/dyaml/source/dyaml/serializer.d',
    'external/dyaml/source/dyaml/style.d',
    'external/dyaml/source/dyaml/tagdirective.d',
    'external/dyaml/source/dyaml/test/common.d',
    'external/dyaml/source/dyaml/test/compare.d',
    'external/dyaml/source/dyaml/test/constructor.d',
    'external/dyaml/source/dyaml/test/emitter.d',
    'external/dyaml/source/dyaml/test/errors.d',
    'external/dyaml/source/dyaml/test/inputoutput.d',
    'external/dyaml/source/dyaml/test/reader.d',
    'external/dyaml/source/dyaml/test/representer.d',
    'external/dyaml/source/dyaml/test/resolver.d',
    'external/dyaml/source/dyaml/test/tokens.d',
    'external/dyaml/source/dyaml/token.d',
    'external/dyaml/source/dyaml/emitter.d',
    'external/dyaml/source/dyaml/exception.d',
    'external/dyaml/source/dyaml/loader.d',
    'external/dyaml/source/dyaml/node.d',
    'external/dyaml/source/dyaml/reader.d',
    'external/dyaml/source/dyaml/representer.d',
    'external/dyaml/source/dyaml/resolver.d',
    'external/dyaml/source/dyaml/scanner.d',
]

libmoss_config_sources += aux_config_sources

# Expose source dependencies
libmoss_config_includes = [
	include_directories('source'),
	include_directories('external/dyaml/source'),
	include_directories('external/tinyendian/source'),
]

# Compile as a static library 
libmoss_config = static_library(
	'moss-config',
	libmoss_config_sources,
	install: installFiles,
	include_directories: libmoss_config_includes,
)

# Allow linking to us
link_libmoss_config = declare_dependency(
	link_with: libmoss_config,
	include_directories: libmoss_config_includes,
)

# Installed system-wide?
if installFiles
	# Install source for other D applications
	install_subdir('source/moss', install_dir: 'include/d/moss-config')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'moss-config',
		libraries: libmoss_config,
		subdirs: 'd/moss-config',
		version: meson.project_version(),
		description: 'moss-config module'
	)
endif
