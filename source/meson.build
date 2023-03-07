# Required components
components = [
    'core',
    'config',
    # 'db',
    # 'deps',
    # 'fetcher',
    # 'format'
]

# dlang -I from source/*
root_includedir = include_directories('.')

foreach component : components
    subdir('moss' / component)
endforeach
