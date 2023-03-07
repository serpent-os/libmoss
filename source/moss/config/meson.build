# moss-config

libmoss_config_sources = [
    'package.d',
    'io/package.d',
    'io/schema.d',
    'io/snippet.d',
    'io/configuration.d',
    'profile.d',
    'repo.d',
]

libmoss_config = static_library(
    'moss-config',
    libmoss_config_sources,
    install: false,
    include_directories: [root_includedir],
    dependencies: [
        link_libyaml,
    ],
)

link_libmoss_config = declare_dependency(
    link_whole: libmoss_config,
    include_directories: [root_includedir],
    dependencies: [
        link_libyaml,
    ]
)
