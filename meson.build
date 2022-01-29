project(
	'moss-fetcher',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

dep_libcurl = dependency('libcurl', version: '>= 7.76.1')

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

# Package sources
fetcher_sources = [
    'source/moss/fetcher/queue.d',
    'source/moss/fetcher/package.d',
    'source/moss/fetcher/result.d',
    'source/moss/fetcher/messaging.d',
    'source/moss/fetcher/worker.d',
    'source/moss/fetcher/controller.d',
]

# Expose source dependencies
libmoss_fetcher_includes = [
	include_directories('source'),
]

# Compile as a static library 
libmoss_fetcher = static_library(
	'moss-fetcher',
	fetcher_sources,
	install: installFiles,
    dependencies: [link_libmoss_core, dep_libcurl],
	include_directories: libmoss_fetcher_includes,
)

# Allow linking to us
link_libmoss_fetcher = declare_dependency(
	link_whole: libmoss_fetcher,
	include_directories: libmoss_fetcher_includes,
	dependencies: [link_libmoss_core, dep_libcurl],
)

# Installed system-wide?
if installFiles
	
	# Install source for other D applications
	install_subdir('source/moss', install_dir: 'include/d/moss-fetcher')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'moss-fetcher',
		libraries: libmoss_fetcher,
		subdirs: 'd/moss-fetcher',
		version: meson.project_version(),
		description: 'moss-fetcher module'
	)
endif
