project(
    'libmoss',
    ['c', 'd'],
    version: '1.2.1',
    license: [
        'Zlib'
    ]
)

# set up convenient debugging flags for mixins
add_project_arguments('--mixin=mixin_generated_code.txt', language : 'd')

# Grab our config
with_moss_config = get_option('with-config')
with_moss_db = get_option('with-db')
with_moss_deps = get_option('with-deps')
with_moss_fetcher = get_option('with-fetcher')
with_moss_format = get_option('with-format')
with_moss_fetcher_http = false
with_moss_fetcher_git = false
with_moss_format_binary = false
with_moss_format_source = false

# Determine moss-format build config
if with_moss_format == 'true'
    with_moss_format_binary = true
    with_moss_format_source = true
elif with_moss_format == 'source'
    with_moss_format_binary = false
    with_moss_format_source = true
elif with_moss_format == 'binary'
    with_moss_format_binary = true
    with_moss_format_source = false
else
    with_moss_format_binary = false
    with_moss_format_source = false
endif

# Determine moss-fetcher build config
if with_moss_fetcher == 'true'
    with_moss_fetcher_http = true
    with_moss_fetcher_git = true
elif with_moss_fetcher == 'http'
    with_moss_fetcher_http = true
    with_moss_fetcher_git = false
elif with_moss_fetcher == 'git'
    with_moss_fetcher_http = false
    with_moss_fetcher_git = true
else
    with_moss_fetcher_http = false
    with_moss_fetcher_git = false
endif

# ddbus binding
ddbus = subproject('ddbus',
    default_options: [
        'default_library=static'
    ])
link_ddbus = ddbus.get_variable('link_ddbus')

# libgit2 binding
if with_moss_fetcher_git
    libgit2 = subproject('libgit2-d',
        default_options: [
            'default_library=static'
        ])
    link_libgit2 = libgit2.get_variable('link_libgit2')
endif

# lmdb binding
if with_moss_db
    lmdb = subproject('lmdb-d',
        default_options: [
            'default_library=static'
        ])
    link_lmdb = lmdb.get_variable('link_liblmdb')
endif

# xxhash binding
if with_moss_format_binary or with_moss_deps
    xxhash = subproject('xxhash-d',
        default_options: [
            'default_library=static'
        ])
    link_xxhash = xxhash.get_variable('link_libxxhash')
endif

# zstd binding
if with_moss_format_binary
    zstdoubledee = subproject('zstdoubledee',
        default_options: [
            'default_library=static'
        ])
    link_zstd = zstdoubledee.get_variable('link_libzstdoubledee')
endif

# yaml / elf-d dependencies, we encapsulate in our own meson.builds
subdir('vendor')

subdir('source')

report = [
    '    Build configuration:',
    '    ====================',
    '',
    '    moss-core:                              always',
    '    moss-config:                            @0@'.format(with_moss_config),
    '    moss-db:                                @0@'.format(with_moss_db),
    '    moss-deps:                              @0@'.format(with_moss_deps),
    '    moss-format (binary):                   @0@'.format(with_moss_format_binary),
    '    moss-format (source):                   @0@'.format(with_moss_format_source),
    '    moss-fetcher (http):                    @0@'.format(with_moss_fetcher_http),
    '    moss-fetcher (git):                     @0@'.format(with_moss_fetcher_git),
]

# Output some stuff to validate the build config
message('\n\n\n' + '\n'.join(report) + '\n\n')
