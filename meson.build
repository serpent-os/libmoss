project(
	'moss-db',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

dep_rocksdb = dependency('rocksdb', version: '>= 6.15.5').partial_dependency(links: true, link_args: true)

# Grab moss-core
moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

# Package sources
libmoss_db_sources = [
	'source/moss/db/rocksdb/bucket.d',
	'source/moss/db/rocksdb/db.d',
	'source/moss/db/rocksdb/iterator.d',
	'source/moss/db/rocksdb/package.d',
	'source/moss/db/rocksdb/tests.d',
	'source/moss/db/rocksdb/transform.d',
	'source/moss/db/encoding.d',
	'source/moss/db/entry.d',
	'source/moss/db/interfaces.d',
	'source/moss/db/package.d',
]

aux_db_sources = [
	'external/rocksdb-binding/src/rocksdb/batch.d',
	'external/rocksdb-binding/src/rocksdb/binding.d',
	'external/rocksdb-binding/src/rocksdb/env.d',
	'external/rocksdb-binding/src/rocksdb/filterpolicy.d',
	'external/rocksdb-binding/src/rocksdb/iterator.d',
	'external/rocksdb-binding/src/rocksdb/package.d',
	'external/rocksdb-binding/src/rocksdb/queryable.d',
	'external/rocksdb-binding/src/rocksdb/slice.d',
	'external/rocksdb-binding/src/rocksdb/slicetransform.d',
	'external/rocksdb-binding/src/rocksdb/snapshot.d',
	'external/rocksdb-binding/src/rocksdb/options.d',
	'external/rocksdb-binding/src/rocksdb/columnfamily.d',
	'external/rocksdb-binding/src/rocksdb/comparator.d',
	'external/rocksdb-binding/src/rocksdb/database.d',
]

libmoss_db_sources += aux_db_sources

# Expose source dependencies
libmoss_db_includes = [
	include_directories('source'),
	include_directories('external/rocksdb-binding/src'),
]

# Compile as a static library
libmoss_db = static_library(
	'moss-db',
	libmoss_db_sources,
	install: installFiles,
	dependencies: [link_libmoss_core, dep_rocksdb],
	include_directories: libmoss_db_includes,
)

# Allow linking to us
link_libmoss_db = declare_dependency(
	link_with: libmoss_db,
	include_directories: libmoss_db_includes,
	dependencies: [dep_rocksdb, link_libmoss_core],
)

# Installed system-wide?
if installFiles
	# Install source for other D applications
	install_subdir('source/moss', install_dir: 'include/d/moss-db')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'moss-db',
		libraries: libmoss_db,
		subdirs: 'd/moss-db',
		version: meson.project_version(),
		description: 'moss-db module'
	)
endif
