project(
    'moss-config',
    ['d'],
    version: '0.0.0',
    license: [
        'ZLib',
    ]
)

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
    installFiles = false
endif

# Grab moss-vendor
moss_vendor = subproject('moss-vendor',
    default_options: [
        'with_yaml=true',
    ]
)
link_libmoss_vendor_yaml = moss_vendor.get_variable('link_libmoss_vendor_yaml')

# Package sources
libmoss_config_sources = [
    'source/moss/config/package.d',
    'source/moss/config/io/package.d',
    'source/moss/config/io/schema.d',
    'source/moss/config/io/snippet.d',
    'source/moss/config/io/configuration.d',
    'source/moss/config/repo.d',
]

# Expose source dependencies
libmoss_config_includes = [
    include_directories('source'),
]

# Compile as a static library 
libmoss_config = static_library(
    'moss-config',
    libmoss_config_sources,
    install: installFiles,
    include_directories: libmoss_config_includes,
    dependencies: [
        link_libmoss_vendor_yaml,
    ],
)

# Allow linking to us
link_libmoss_config = declare_dependency(
    link_whole: libmoss_config,
    include_directories: libmoss_config_includes,
    dependencies: [
        link_libmoss_vendor_yaml,
    ]
)

# Installed system-wide?
if installFiles
    # Install source for other D applications
    install_subdir('source/moss', install_dir: 'include/d/moss-config')

    # Generate pkgconfig for linking
    pkgconf.generate(name: 'moss-config',
        libraries: libmoss_config,
        subdirs: 'd/moss-config',
        version: meson.project_version(),
        description: 'moss-config module'
    )
endif

subdir('tests')