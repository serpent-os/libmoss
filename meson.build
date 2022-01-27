project(
	'moss-deps',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

dep_libxhhash = dependency('libxxhash', version: '>= 0.8.1')

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

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

aux_deps_sources = [
	'external/elf-d/source/elf/low.d',
	'external/elf-d/source/elf/low32.d',
	'external/elf-d/source/elf/low64.d',
	'external/elf-d/source/elf/meta.d',
	'external/elf-d/source/elf/package.d',
	'external/elf-d/source/elf/sections/debugabbrev/package.d',
	'external/elf-d/source/elf/sections/debugline/debugline32.d',
	'external/elf-d/source/elf/sections/debugline/debugline64.d',
	'external/elf-d/source/elf/sections/debugline/package.d',
	'external/elf-d/source/elf/sections/dynamiclinkingtable.d',
	'external/elf-d/source/elf/sections/note.d',
	'external/elf-d/source/elf/sections/package.d',
	'external/elf-d/source/elf/sections/stringtable.d',
	'external/elf-d/source/elf/sections/symboltable.d',
]

deps_sources += aux_deps_sources

# Expose source dependencies
libmoss_deps_includes = [
	include_directories('source'),
    include_directories('external/elf-d/source'),
    include_directories('external/xxhash-d/source'),
]

# Compile as a static library 
libmoss_deps = static_library(
	'moss-deps',
	deps_sources,
	install: installFiles,
	dependencies: [link_libmoss_core, dep_libxhhash],
	include_directories: libmoss_deps_includes,
)

# Allow linking to us
link_libmoss_deps = declare_dependency(
	link_with: libmoss_deps,
	include_directories: libmoss_deps_includes,
	dependencies: [link_libmoss_core, dep_libxhhash],
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
