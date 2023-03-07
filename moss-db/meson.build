project(
	'moss-db',
	['d'],
	version: '0.0.4',
	license: [
		'Zlib',
	]
)

# Grab moss-core
moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

# Grab moss-vendor
moss_vendor = subproject('moss-vendor',
	default_options: [
		'with_lmdb=true',
	]
)

link_libmoss_vendor_lmdb = moss_vendor.get_variable('link_libmoss_vendor_lmdb')

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

# Package sources
libmoss_db_sources = [
	'source/moss/db/keyvalue/interfaces.d',
	'source/moss/db/keyvalue/package.d',
	'source/moss/db/keyvalue/driver/lmdb/transaction.d',
	'source/moss/db/keyvalue/driver/lmdb/driver.d',
	'source/moss/db/keyvalue/driver/lmdb/bucket_iterator.d',
	'source/moss/db/keyvalue/driver/lmdb/package.d',
	'source/moss/db/keyvalue/driver/lmdb/iterator.d',
	'source/moss/db/keyvalue/driver/package.d',
	'source/moss/db/keyvalue/orm/save.d',
	'source/moss/db/keyvalue/orm/create.d',
	'source/moss/db/keyvalue/orm/load.d',
	'source/moss/db/keyvalue/orm/types.d',
	'source/moss/db/keyvalue/orm/tests.d',
	'source/moss/db/keyvalue/orm/package.d',
	'source/moss/db/keyvalue/orm/list.d',
	'source/moss/db/keyvalue/orm/remove.d',
	'source/moss/db/keyvalue/errors.d',
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
	dependencies: [link_libmoss_core, link_libmoss_vendor_lmdb],
	include_directories: libmoss_db_includes,
)

# Allow linking to us
link_libmoss_db = declare_dependency(
	link_whole: libmoss_db,
	include_directories: libmoss_db_includes,
	dependencies: [link_libmoss_core, link_libmoss_vendor_lmdb],
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
