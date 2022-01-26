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
config_sources = [
	'source/moss/config/package.d',
	'source/moss/config/io/package.d',
	'source/moss/config/io/schema.d',
	'source/moss/config/io/snippet.d',
	'source/moss/config/io/configuration.d',
	'source/moss/config/repo.d',
]

# Expose source dependencies
libconfig_includes = [
	include_directories('source'),
	include_directories('external/dyaml/source'),
	include_directories('external/tinyendian/source'),
]

# Compile as a static library 
libconfig = static_library(
	'moss-config',
	config_sources,
	install: installFiles,
	include_directories: libconfig_includes,
)

# Allow linking to us
link_libconfig = declare_dependency(
	link_with: libconfig,
	include_directories: libconfig_includes,
)

# Installed system-wide?
if installFiles
	# Install source for other D applications
	install_subdir('source/moss', install_dir: 'include/d/moss-config')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'moss-config',
		libraries: libconfig,
		subdirs: 'd/moss-config',
		version: meson.project_version(),
		description: 'moss-config module'
	)
endif
