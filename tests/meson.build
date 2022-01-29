## Testing support

tests = [
    'simple',
]

foreach testName : tests
    testExec = executable(testName,
        [
            '@0@.d'.format(testName),
            'test_main.d',
        ],
        d_unittest: true,
        install: false,
        include_directories: libmoss_config_includes,
        dependencies: [
            link_libmoss_config,
        ]
    )
    test('test-@0@'.format(testName), testExec)
endforeach