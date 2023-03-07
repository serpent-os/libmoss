project(
	'xxhash-d',
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

dep_libxxhash = dependency('libxxhash', version: '>= 0.8.1')

# Package sources
deps_sources = [
    'source/xxhash/binding.d',
    'source/xxhash/package.d',
    'source/xxhash/util.d',
]

# Expose source dependencies
libxxhash_includes = [
	include_directories('source'),
]

# Compile as a static library 
libxxhash = static_library(
	'xxhash-d',
	deps_sources,
	install: installFiles,
	dependencies: [
		dep_libxxhash,
	],
	include_directories: libxxhash_includes,
)

# Allow linking to us
link_libxxhash = declare_dependency(
	link_whole: libxxhash,
	include_directories: libxxhash_includes,
	dependencies: [
        dep_libxxhash
	],
)

# Installed system-wide?
if installFiles
	
	# Install source for other D applications
	install_subdir('source/xxhash', install_dir: 'include/d')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'xxhash-d',
		libraries: libxxhash,
		subdirs: 'd/xxhash',
		version: meson.project_version(),
		description: 'xxhash-d module'
	)
endif
