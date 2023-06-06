# moss-deps

deps_sources = [
	'package.d',
	'analysis/package.d',
	'analysis/bucket.d',
	'analysis/fileinfo.d',
	'analysis/analyser.d',
	'analysis/chain.d',
	'analysis/elves.d',
	'registry/candidate.d',
	'registry/job.d',
	'registry/plugin.d',
	'registry/item.d',
	'registry/manager.d',
	'registry/transaction.d',
	'registry/package.d',
	'registry/fauxplugin.d',
	'dag.d',
	'dependency.d',
]

libmoss_deps = static_library(
	'moss-deps',
	deps_sources,
	install: false,
	dependencies: [
		link_libmoss_core,
		link_libelf,
		link_xxhash,
	],
	include_directories: [root_includedir],
)

link_libmoss_deps = declare_dependency(
	link_whole: libmoss_deps,
	include_directories: [root_includedir],
	dependencies: [
		link_libmoss_core,
		link_libelf,
		link_xxhash,
	],
)
