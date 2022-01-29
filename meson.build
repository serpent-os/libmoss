project('moss-vendor',
    ['d'],
    version: '0.0.0',
    license: [
        'ZLib',
    ]
)

# We don't support system wide installation as this should be handled properly
# by packaging for each component.
yaml_sources = [
    'tinyendian/source/tinyendian.d',
    'dyaml/source/dyaml/composer.d',
    'dyaml/source/dyaml/constructor.d',
    'dyaml/source/dyaml/dumper.d',
    'dyaml/source/dyaml/emitter.d',
    'dyaml/source/dyaml/encoding.d',
    'dyaml/source/dyaml/escapes.d',
    'dyaml/source/dyaml/event.d',
    'dyaml/source/dyaml/exception.d',
    'dyaml/source/dyaml/linebreak.d',
    'dyaml/source/dyaml/loader.d',
    'dyaml/source/dyaml/package.d',
    'dyaml/source/dyaml/parser.d',
    'dyaml/source/dyaml/queue.d',
    'dyaml/source/dyaml/reader.d',
    'dyaml/source/dyaml/representer.d',
    'dyaml/source/dyaml/resolver.d',
    'dyaml/source/dyaml/scanner.d',
    'dyaml/source/dyaml/serializer.d',
    'dyaml/source/dyaml/style.d',
    'dyaml/source/dyaml/tagdirective.d',
    'dyaml/source/dyaml/token.d',
    'dyaml/source/dyaml/node.d',
]

yaml_includes = [
    include_directories('tinyendian/source'),
    include_directories('dyaml/source'),
]

libvendor_yaml = static_library(
    'vendor_yaml',
    yaml_sources,
    install: false,
    include_directories: yaml_includes
)

link_libvendor_yaml = declare_dependency(
    link_with: libvendor_yaml,
    include_directories: yaml_includes,
)