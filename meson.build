project(
	'moss-core',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

pkgconf = import('pkgconfig')

# Package sources
core_sources = [
	'source/moss/core/cli/package.d',
	'source/moss/core/download/manager.d',
	'source/moss/core/download/package.d',
	'source/moss/core/download/store.d',
	'source/moss/core/platform.d',
	'source/moss/core/store.d',
	'source/moss/core/encoding.d',
	'source/moss/core/package.d',
	'source/moss/core/util.d',
	'source/moss/core/ioutil.d',
	'source/moss/core/c.d',
	'source/moss/core/fetchcontext.d',
]

# Expose source dependencies
libcore_includes = [
	include_directories('source'),
]

# Compile as a static library 
libcore = static_library(
	'moss-core',
	core_sources,
	install: true,
	include_directories: libcore_includes,
)

# Allow linking to us
link_libcore = declare_dependency(
	link_with: libcore,
	include_directories: libcore_includes,
)

# Installed system-wide?
if not meson.is_subproject()
	
	# Install source for other D applications
	install_subdir('source/moss', install_dir: 'include/d/moss-core')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'moss-core',
		libraries: libcore,
		subdirs: 'd/moss-core',
		version: meson.project_version(),
		description: 'moss-core module'
	)
endif
