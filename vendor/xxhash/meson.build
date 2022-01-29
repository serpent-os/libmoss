### xxhash

dep_libxxhash = dependency('libxxhash', version: '>= 0.8.1')

libmoss_vendor_xxhash_sources = [
    'xxhash-d/source/xxhash/binding.d',
    'xxhash-d/source/xxhash/package.d',
    'xxhash-d/source/xxhash/util.d',
]

libmoss_vendor_xxhash_includes = [
    include_directories('xxhash-d/source'),
]

libmoss_vendor_xxhash = static_library(
    'moss-vendor-xxhash',
    libmoss_vendor_xxhash_sources,
    install: false,
    include_directories: libmoss_vendor_xxhash_includes,
    dependencies: [dep_libxxhash]
)

link_libmoss_vendor_xxhash = declare_dependency(
    link_with: libmoss_vendor_xxhash,
    include_directories: libmoss_vendor_xxhash_includes,
    dependencies: [dep_libxxhash]
)