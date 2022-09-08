project(
	'moss-core',
	['d'],
	version: '0.0.0',
	license: [
		'Zlib',
	]
)

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

# Package sources
libmoss_core_sources = [
	'source/moss/core/cli/package.d',
	'source/moss/core/download/manager.d',
	'source/moss/core/download/package.d',
	'source/moss/core/download/store.d',
	'source/moss/core/platform.d',
	'source/moss/core/store.d',
	'source/moss/core/encoding.d',
	'source/moss/core/errors.d',
	'source/moss/core/package.d',
	'source/moss/core/util.d',
	'source/moss/core/ioutil.d',
	'source/moss/core/c.d',
	'source/moss/core/fetchcontext.d',
	'source/moss/core/mounts.d',
	'source/moss/core/logger.d',
]

# Expose source dependencies
libmoss_core_includes = [
	include_directories('source'),
]

# Compile as a static library 
libmoss_core = static_library(
	'moss-core',
	libmoss_core_sources,
	install: installFiles,
	include_directories: libmoss_core_includes,
)

# Allow linking to us
link_libmoss_core = declare_dependency(
	link_whole: libmoss_core,
	include_directories: libmoss_core_includes,
)

# Installed system-wide?
if installFiles
	
	# Install source for other D applications
	install_subdir('source/moss', install_dir: 'include/d/moss-core')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'moss-core',
		libraries: libmoss_core,
		subdirs: 'd/moss-core',
		version: meson.project_version(),
		description: 'moss-core module'
	)
endif
