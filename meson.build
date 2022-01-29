project(
	'moss-db',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

# Grab moss-core
moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

# Grab moss-vendor
moss_vendor = subproject('moss-vendor',
	default_options: [
		'with_rocksdb=true',
	]
)

link_libmoss_vendor_rocksdb = moss_vendor.get_variable('link_libmoss_vendor_rocksdb')

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

# Expose source dependencies
libmoss_db_includes = [
	include_directories('source'),
]

# Compile as a static library
libmoss_db = static_library(
	'moss-db',
	libmoss_db_sources,
	install: installFiles,
	dependencies: [link_libmoss_core, link_libmoss_vendor_rocksdb],
	include_directories: libmoss_db_includes,
)

# Allow linking to us
link_libmoss_db = declare_dependency(
	link_with: libmoss_db,
	include_directories: libmoss_db_includes,
	dependencies: [link_libmoss_core, link_libmoss_vendor_rocksdb],
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
