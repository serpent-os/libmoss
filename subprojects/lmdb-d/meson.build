project(
	'lmdb-d',
	['d', 'c'],
	version: '0.0.2',
	license: [
		'Zlib',
	]
)

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

# Revisit for potential pkgconfig(lmdb) in some distros
c_comp = meson.get_compiler('c')
lmdb_dep = c_comp.find_library('lmdb', required: true)

# Package sources
deps_sources = [
    'source/lmdb/binding.d',
    'source/lmdb/macros.d',
    'source/lmdb/package.d',
]

# Expose source dependencies
liblmdb_includes = [
	include_directories('source'),
]

# Compile as a static library 
liblmdb = static_library(
	'lmdb-d',
	deps_sources,
	install: installFiles,
	dependencies: [
        lmdb_dep,
	],
	include_directories: liblmdb_includes,
)

# Allow linking to us
link_liblmdb = declare_dependency(
	link_whole: liblmdb,
	include_directories: liblmdb_includes,
	dependencies: [
        lmdb_dep,
	],
)

# Installed system-wide?
if installFiles
	
	# Install source for other D applications
	install_subdir('source/lmdb', install_dir: 'include/d')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'lmdb-d',
		libraries: [liblmdb, lmdb_dep],
		subdirs: 'd/lmdb',
		version: meson.project_version(),
		description: 'lmdb-d module'
	)
endif
