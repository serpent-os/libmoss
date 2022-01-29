## rocksdb-binding

dep_rocksdb = dependency('rocksdb', version: '>= 6.15.5').partial_dependency(links: true, link_args: true)

libmoss_vendor_rocksdb_sources = [
	'rocksdb-binding/src/rocksdb/batch.d',
	'rocksdb-binding/src/rocksdb/binding.d',
	'rocksdb-binding/src/rocksdb/env.d',
	'rocksdb-binding/src/rocksdb/filterpolicy.d',
	'rocksdb-binding/src/rocksdb/iterator.d',
	'rocksdb-binding/src/rocksdb/package.d',
	'rocksdb-binding/src/rocksdb/queryable.d',
	'rocksdb-binding/src/rocksdb/slice.d',
	'rocksdb-binding/src/rocksdb/slicetransform.d',
	'rocksdb-binding/src/rocksdb/snapshot.d',
	'rocksdb-binding/src/rocksdb/options.d',
	'rocksdb-binding/src/rocksdb/columnfamily.d',
	'rocksdb-binding/src/rocksdb/comparator.d',
	'rocksdb-binding/src/rocksdb/database.d',
]

libmoss_vendor_rocksdb_includes = [
    include_directories('rocksdb-binding/src'),
]

libmoss_vendor_rocksdb = static_library(
    'moss-vendor-rocksdb',
    libmoss_vendor_rocksdb_sources,
    install: false,
    dependencies: [dep_rocksdb],
    include_directories: libmoss_vendor_rocksdb_includes,
)

link_libmoss_vendor_rocksdb = declare_dependency(
    link_with: libmoss_vendor_rocksdb,
    include_directories: libmoss_vendor_rocksdb_includes,
    dependencies: [dep_rocksdb],
)