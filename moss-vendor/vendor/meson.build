possible_modules = [
    'elf',
    'lmdb',
    'yaml',
    'xxhash',
    'zstd',
]

foreach option : possible_modules
    if get_option('with_@0@'.format(option)) == true
        subdir(option)
    endif
endforeach
