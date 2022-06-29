project(
	'moss-deps',
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

# Grab moss-core
moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

# Grab moss-vendor
moss_vendor = subproject('moss-vendor',
	default_options: [
		'with_elf=true',
		'with_xxhash=true',
	]
)

link_libmoss_vendor_elf = moss_vendor.get_variable('link_libmoss_vendor_elf')
link_libmoss_vendor_xxhash = moss_vendor.get_variable('link_libmoss_vendor_xxhash')

# Package sources
deps_sources = [
    'source/moss/deps/package.d',
    'source/moss/deps/analysis/package.d',
    'source/moss/deps/analysis/bucket.d',
    'source/moss/deps/analysis/fileinfo.d',
    'source/moss/deps/analysis/analyser.d',
    'source/moss/deps/analysis/chain.d',
    'source/moss/deps/analysis/elves.d',
    'source/moss/deps/registry/candidate.d',
    'source/moss/deps/registry/plugin.d',
    'source/moss/deps/registry/item.d',
    'source/moss/deps/registry/manager.d',
    'source/moss/deps/registry/transaction.d',
    'source/moss/deps/registry/package.d',
    'source/moss/deps/registry/fauxplugin.d',
    'source/moss/deps/digraph.d',
    'source/moss/deps/dependency.d',
]

# Expose source dependencies
libmoss_deps_includes = [
	include_directories('source'),
]

# Compile as a static library 
libmoss_deps = static_library(
	'moss-deps',
	deps_sources,
	install: installFiles,
	dependencies: [
		link_libmoss_core,
		link_libmoss_vendor_elf,
		link_libmoss_vendor_xxhash,
	],
	include_directories: libmoss_deps_includes,
)

# Allow linking to us
link_libmoss_deps = declare_dependency(
	link_whole: libmoss_deps,
	include_directories: libmoss_deps_includes,
	dependencies: [
		link_libmoss_core,
		link_libmoss_vendor_elf,
		link_libmoss_vendor_xxhash,
	],
)

# Installed system-wide?
if installFiles
	
	# Install source for other D applications
	install_subdir('source/moss', install_dir: 'include/d/moss-deps')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'moss-deps',
		libraries: libmoss_deps,
		subdirs: 'd/moss-deps',
		version: meson.project_version(),
		description: 'moss-deps module'
	)
endif
