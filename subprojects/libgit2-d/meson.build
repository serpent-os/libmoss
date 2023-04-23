project(
	'libgit2-d',
	['d'],
	# X.Y.Z.#, X.Y.Z refers to the upstream libgit2 version, # refers to our patch
	# version
	version: '1.6.2.0',
	license: [
		'Zlib',
	]
)

pkgconf = import('pkgconfig')
installFiles = true
if meson.is_subproject()
	installFiles = false
endif

# Dependencies
openssl = dependency('openssl', static: get_option('default_library') == 'static')
zlib = dependency('zlib', static: get_option('default_library') == 'static')

# Setup cmake subproject
cmake = import('cmake')
opt_var = cmake.subproject_options()
opt_var.add_cmake_defines({
	'USE_HTTP_PARSER': 'builtin',
	'USE_HTTPS': 'OpenSSL',
	'REGEX_BACKEND': 'builtin',
	'USE_BUNDLED_ZLIB': false,
	'USE_SSH': false,
	'BUILD_TESTS': false,
	'BUILD_SHARED_LIBS': false,
})
opt_var.set_override_option('c_std', 'gnu89')
opt_var.set_override_option('warning_level', '0')

# Call the cmake subproject and extract the target
libgit2 = cmake.subproject(
	'libgit2',
	options: opt_var,
)
# We're not using dependency because it will pass the C headers to the D
# compiler
libgit2_tgt = libgit2.target('libgit2package')

# Package sources
deps_sources = [
	'source/git2/bindings.d',
	'source/git2/enums.d',
	'source/git2/extra.d',
	'source/git2/package.d',
]

# Expose source dependencies
libgit2_includes = [
	include_directories('source'),
]

# Compile as a static library 
libgit2 = static_library(
	'libgit2-d',
	deps_sources,
	install: installFiles,
	link_with: [libgit2_tgt],
	dependencies: [openssl, zlib],
	include_directories: libgit2_includes,
)

# Allow linking to us
link_libgit2 = declare_dependency(
	link_whole: libgit2,
	link_with: [libgit2_tgt],
	dependencies: [openssl, zlib],
	include_directories: libgit2_includes,
)

# Installed system-wide?
if installFiles
	
	# Install source for other D applications
	install_subdir('source/git2', install_dir: 'include/d')

	# Generate pkgconfig for linking
	pkgconf.generate(name: 'libgit2-d',
		libraries: libgit2,
		subdirs: 'd/git2',
		version: meson.project_version(),
		description: 'libgit2-d module'
	)
endif
