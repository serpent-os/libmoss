### zstd

dep_libzstd = dependency('libzstd', version: '>= 1.5.0')

libmoss_vendor_zstd_sources = [
    'zstd/source/zstd/c/zstd.d',
    'zstd/source/zstd/common.d',
    'zstd/source/zstd/compress.d',
    'zstd/source/zstd/decompress.d',
    'zstd/source/zstd/package.d',
]

libmoss_vendor_zstd_includes = [
    include_directories('zstd/source')
]

libmoss_vendor_zstd = static_library(
    'moss-vendor-zstd',
    libmoss_vendor_zstd_sources,
    install: false,
    include_directories: libmoss_vendor_zstd_includes,
    dependencies: [dep_libzstd],
)

link_libmoss_vendor_zstd = declare_dependency(
    link_with: libmoss_vendor_zstd,
    include_directories: libmoss_vendor_zstd_includes,
    dependencies: [dep_libzstd]
)