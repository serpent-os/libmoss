project(
    'libmoss',
    ['c', 'd'],
    version: '0.1.0',
    license: [
        'Zlib'
    ]
)

# Bindings for db/format functionality
external_projects = [
    'lmdb-d',
    'xxhash-d',
    'zstdoubledee'
]

foreach project : external_projects
    subproject(project)
endforeach

# yaml dependencies, we encapsulate in our own meson.builds
subdir('vendor')

subdir('source')
