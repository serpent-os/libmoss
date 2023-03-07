# moss-fetcher

dep_libcurl = dependency('libcurl', version: '>= 7.76.1')

fetcher_sources = [
    'queue.d',
    'package.d',
    'result.d',
    'messaging.d',
    'worker.d',
    'controller.d',
]

libmoss_fetcher = static_library(
	'moss-fetcher',
	fetcher_sources,
	install: false,
    dependencies: [link_libmoss_core, dep_libcurl],
	include_directories: [root_includedir],
)

link_libmoss_fetcher = declare_dependency(
	link_whole: libmoss_fetcher,
	include_directories: [root_includedir],
	dependencies: [link_libmoss_core, dep_libcurl],
)
