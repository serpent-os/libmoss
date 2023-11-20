# libmosscore

libmoss_core_sources = [
    'cli/package.d',
    'download/manager.d',
    'download/package.d',
    'download/store.d',
    'c.d',
    'ftw.d',
    'cpuinfo.d',
    'encoding.d',
    'errors.d',
    'fetchcontext.d',
    'ioutil.d',
    'logger.d',
    'memoryinfo.d',
    'mounts.d',
    'package.d',
    'platform.d',
    'sizing.d',
    'store.d',
    'util.d',
]

core_deps = [link_ddbus]

libmoss_core = static_library(
    'moss-core',
    libmoss_core_sources,
    install: false,
    dependencies: core_deps,
    include_directories: [root_includedir]
)

# Allow individually linking to libmosscore
link_libmoss_core = declare_dependency(
    link_whole: libmoss_core,
    include_directories: [root_includedir],
    dependencies: core_deps,
)
