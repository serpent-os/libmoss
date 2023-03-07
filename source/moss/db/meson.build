# moss-db

libmoss_db_sources = [
	'keyvalue/interfaces.d',
	'keyvalue/package.d',
	'keyvalue/driver/lmdb/transaction.d',
	'keyvalue/driver/lmdb/driver.d',
	'keyvalue/driver/lmdb/bucket_iterator.d',
	'keyvalue/driver/lmdb/package.d',
	'keyvalue/driver/lmdb/iterator.d',
	'keyvalue/driver/package.d',
	'keyvalue/orm/save.d',
	'keyvalue/orm/create.d',
	'keyvalue/orm/load.d',
	'keyvalue/orm/types.d',
	'keyvalue/orm/tests.d',
	'keyvalue/orm/package.d',
	'keyvalue/orm/list.d',
	'keyvalue/orm/remove.d',
	'keyvalue/errors.d',
]

libmoss_db = static_library(
	'moss-db',
	libmoss_db_sources,
	install: false,
	dependencies: [link_libmoss_core, link_lmdb],
	include_directories: [root_includedir],
)

link_libmoss_db = declare_dependency(
	link_with: libmoss_db,
	include_directories: [root_includedir],
	dependencies: [link_libmoss_core, link_lmdb],
)
