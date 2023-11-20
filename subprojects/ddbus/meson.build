project(
	'ddbus',
	['d', 'c'],
	version: '3.0.0',
	license: [
		'Zlib',
	]
)

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

# Revisit for potential pkgconfig(dbus-1) in some distros
c_comp = meson.get_compiler('c')
ddbus_dep = c_comp.find_library('dbus-1', required: true)

# Package sources
deps_sources = [
    'source/ddbus/attributes.d',
    'source/ddbus/bus.d',
    'source/ddbus/c_lib.d',
    'source/ddbus/conv.d',
    'source/ddbus/exception.d',
    'source/ddbus/package.d',
    'source/ddbus/router.d',
    'source/ddbus/simple.d',
    'source/ddbus/thin.d',
    'source/ddbus/util.d',
]

# Expose source dependencies
libddbus_includes = [
	include_directories('source'),
]

# Compile as a static library
ddbus = static_library(
	'ddbus',
	deps_sources,
	install: installFiles,
	dependencies: [
        ddbus_dep,
	],
	include_directories: libddbus_includes,
)

# Allow linking to us
link_ddbus = declare_dependency(
	link_whole: ddbus,
	include_directories: libddbus_includes,
	dependencies: [
            ddbus_dep,
	],
)

# Installed system-wide?
if installFiles

	# Install source for other D applications
	install_subdir('source/ddbus', install_dir: 'include/d')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'ddbus',
		libraries: [libddbus, ddbus_dep],
		subdirs: 'd/ddbus',
		version: meson.project_version(),
		description: 'ddbus module'
	)
endif
