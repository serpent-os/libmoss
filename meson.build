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

libgit2 = subproject(
  'libgit2',
  default_options: ['default_library=static'],
)
libgit2_dep = libgit2.get_variable('libgit2_dep')

# Package sources
deps_sources = [
    'source/git2/bindings.d',
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
	dependencies: [
		libgit2_dep,
	],
	include_directories: libgit2_includes,
)

# Allow linking to us
link_libgit2 = declare_dependency(
	link_whole: libgit2,
	include_directories: libgit2_includes,
	dependencies: [
        libgit2_dep
	],
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
