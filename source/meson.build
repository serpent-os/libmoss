# Required components
components = [
    'core',
    'config',
    'db',
    'deps',
    'fetcher',
    'format'
]

# Mandatory
components = ['core']

if with_moss_config
    components += 'config'
endif

if with_moss_db
    components += 'db'
endif

if with_moss_deps
    components += 'deps'
endif

if with_moss_fetcher
    components += 'fetcher'
endif

if with_moss_format_binary or with_moss_format_source
    components += 'format'
endif

# dlang -I from source/*
root_includedir = include_directories('.')

foreach component : components
    subdir('moss' / component)
endforeach
