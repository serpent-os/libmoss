project(
    'libmoss',
    ['c', 'd'],
    version: '0.1.0',
    license: [
        'Zlib'
    ]
)

# lmdb binding
lmdb = subproject('lmdb-d')
link_lmdb = lmdb.get_variable('link_liblmdb')

# xxhash binding
xxhash = subproject('xxhash-d')
link_xxhash = xxhash.get_variable('link_libxxhash')

# zstd binding
zstdoubledee = subproject('zstdoubledee')
link_zstd = zstdoubledee.get_variable('link_libzstdoubledee')

# yaml / elf-d dependencies, we encapsulate in our own meson.builds
subdir('vendor')

subdir('source')
