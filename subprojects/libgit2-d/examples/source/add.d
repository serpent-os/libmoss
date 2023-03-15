/*
 * libgit2 "add" example - shows how to modify the index
 *
 * Written by the libgit2 contributors
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain
 * worldwide. This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see
 * <http://creativecommons.org/publicdomain/zero/1.0/>.
 */
module libgit2_d.example.add;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.example.args;
private static import libgit2_d.example.common;
private static import libgit2_d.index;
private static import libgit2_d.repository;
private static import libgit2_d.status;
private static import libgit2_d.strarray;
private static import libgit2_d.types;

package:

/**
 * The following example demonstrates how to add files with libgit2.
 *
 * It will use the repository in the current working directory, and act
 * on files passed as its parameters.
 *
 * Recognized options are:
 *   -v/--verbose: show the file's status after acting on it.
 *   -n/--dry-run: do not actually change the index.
 *   -u/--update: update the index instead of adding to it.
 */

public enum index_mode
{
	INDEX_NONE,
	INDEX_ADD,
}

//Declaration name in C language
public enum
{
	INDEX_NONE = .index_mode.INDEX_NONE,
	INDEX_ADD = .index_mode.INDEX_ADD,
}

public struct index_options
{
	int dry_run;
	int verbose;
	libgit2_d.types.git_repository* repo;
	.index_mode mode;
	int add_update;
}

/* Forward declarations for helpers */
//private void parse_opts(int* options, int* count, int argc, char*[] argv);
//void init_array(libgit2_d.strarray.git_strarray* array, int argc, char** argv);
//int print_matched_cb(const (char)* path, const (char)* matched_pathspec, void* payload);

extern (C)
nothrow @nogc
public int lg2_add(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);

		/* Parse the options & arguments. */
		.index_options options = .index_options.init;
		options.mode = .index_mode.INDEX_ADD;
		.parse_opts(null, &options, &args);

		libgit2_d.strarray.git_strarray array = libgit2_d.strarray.git_strarray.init;
		libgit2_d.example.args.strarray_from_args(&array, &args);

		/* Grab the repository's index. */
		libgit2_d.types.git_index* index;
		libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_index(&index, repo), "Could not open repository index", null);

		libgit2_d.index.git_index_matched_path_cb matched_cb = null;

		/* Setup a callback if the requested options need it */
		if ((options.verbose) || (options.dry_run)) {
			matched_cb = &.print_matched_cb;
		}

		options.repo = repo;

		if (options.add_update) {
			libgit2_d.index.git_index_update_all(index, &array, matched_cb, &options);
		} else {
			libgit2_d.index.git_index_add_all(index, &array, 0, matched_cb, &options);
		}

		/* Cleanup memory */
		libgit2_d.index.git_index_write(index);
		libgit2_d.index.git_index_free(index);

		return 0;
	}

/*
 * This callback is called for each file under consideration by
 * git_index_(update|add)_all above.
 * It makes uses of the callback's ability to abort the action.
 */
extern (C)
nothrow @nogc
public int print_matched_cb(const (char)* path, const (char)* matched_pathspec, void* payload)

	in
	{
	}

	do
	{
		.index_options opts = *cast(.index_options*)(payload);
		uint status;
		//cast(void)(matched_pathspec);

		/* Get the file status */
		if (libgit2_d.status.git_status_file(&status, opts.repo, path) < 0) {
			return -1;
		}

		int ret;

		if ((status & libgit2_d.status.git_status_t.GIT_STATUS_WT_MODIFIED) || (status & libgit2_d.status.git_status_t.GIT_STATUS_WT_NEW)) {
			core.stdc.stdio.printf("add '%s'\n", path);
			ret = 0;
		} else {
			ret = 1;
		}

		if (opts.dry_run) {
			ret = 1;
		}

		return ret;
	}

nothrow @nogc
public void init_array(libgit2_d.strarray.git_strarray* array, int argc, char** argv)

	in
	{
	}

	do
	{
		array.count = argc;
		array.strings = cast(char**)(core.stdc.stdlib.calloc(array.count, (char*).sizeof));
		assert(array.strings != null);

		for (uint i = 0; i < array.count; i++) {
			array.strings[i] = argv[i];
		}

		return;
	}

nothrow @nogc
public void print_usage()

	in
	{
	}

	do
	{
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: add [options] [--] file-spec [file-spec] [...]\n\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "\t-n, --dry-run    dry run\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "\t-v, --verbose    be verbose\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "\t-u, --update     update tracked files\n");
		core.stdc.stdlib.exit(1);
	}

nothrow @nogc
private void parse_opts(const (char)** repo_path, .index_options* opts, libgit2_d.example.args.args_info* args)

	in
	{
	}

	do
	{
		if (args.argc <= 1) {
			.print_usage();
		}

		for (args.pos = 1; args.pos < args.argc; ++args.pos) {
			const (char)* curr = args.argv[args.pos];

			if (curr[0] != '-') {
				if (!core.stdc.string.strcmp("add", curr)) {
					opts.mode = .index_mode.INDEX_ADD;

					continue;
				} else if (opts.mode == .index_mode.INDEX_NONE) {
					core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "missing command: %s", curr);
					.print_usage();

					break;
				} else {
					/* We might be looking at a filename */
					break;
				}
			} else if ((libgit2_d.example.args.match_bool_arg(&opts.verbose, args, "--verbose")) || (libgit2_d.example.args.match_bool_arg(&opts.dry_run, args, "--dry-run")) || (libgit2_d.example.args.match_str_arg(repo_path, args, "--git-dir")) || ((opts.mode == .index_mode.INDEX_ADD) && (libgit2_d.example.args.match_bool_arg(&opts.add_update, args, "--update")))) {
				continue;
			} else if (libgit2_d.example.args.match_bool_arg(null, args, "--help")) {
				.print_usage();

				break;
			} else if (libgit2_d.example.args.match_arg_separator(args)) {
				break;
			} else {
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "Unsupported option %s.\n", curr);
				.print_usage();
			}
		}
	}
