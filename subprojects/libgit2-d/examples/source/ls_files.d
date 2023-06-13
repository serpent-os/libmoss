/*
 * libgit2 "ls-files" example - shows how to view all files currently in the index
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
module libgit2_d.example.ls_files;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.index;
private static import libgit2_d.repository;
private static import libgit2_d.types;

package:

/**
 * This example demonstrates the libgit2 index APIs to roughly
 * simulate the output of `git ls-files`.
 * `git ls-files` has many options and this currently does not show them.
 *
 * `git ls-files` base command shows all paths in the index at that time.
 * This includes staged and committed files, but unstaged files will not display.
 *
 * This currently supports the default behavior and the `--error-unmatch` option.
 */

public struct ls_options
{
	int error_unmatch;
	char*[1024] files;
	size_t file_count;
}

nothrow @nogc
private void usage(const (char)* message, const (char)* arg)

	in
	{
	}

	do
	{
		if ((message != null) && (arg != null)) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "%s: %s\n", message, arg);
		} else if (message != null) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "%s\n", message);
		}

		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: ls-files [--error-unmatch] [--] [<file>...]\n");
		core.stdc.stdlib.exit(1);
	}

nothrow @nogc
private int parse_options(.ls_options* opts, int argc, char** argv)

	in
	{
	}

	do
	{
		core.stdc.string.memset(opts, 0, .ls_options.sizeof);

		if (argc < 2) {
			return 0;
		}

		int parsing_files = 0;

		for (int i = 1; i < argc; ++i) {
			char* a = argv[i];

			/* if it doesn't start with a '-' or is after the '--' then it is a file */
			if ((a[0] != '-') || (parsing_files)) {
				parsing_files = 1;

				/* watch for overflows (just in case) */
				if (opts.file_count == 1024) {
					core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "ls-files can only support 1024 files at this time.\n");

					return -1;
				}

				opts.files[opts.file_count++] = a;
			} else if (!core.stdc.string.strcmp(a, "--")) {
				parsing_files = 1;
			} else if (!core.stdc.string.strcmp(a, "--error-unmatch")) {
				opts.error_unmatch = 1;
			} else {
				.usage("Unsupported argument", a);

				return -1;
			}
		}

		return 0;
	}

nothrow @nogc
private int print_paths(.ls_options* opts, libgit2_d.types.git_index* index)

	in
	{
	}

	do
	{
		const (libgit2_d.index.git_index_entry)* entry;

		/* if there are no files explicitly listed by the user print all entries in the index */
		if (opts.file_count == 0) {
			size_t entry_count = libgit2_d.index.git_index_entrycount(index);

			for (size_t i = 0; i < entry_count; i++) {
				entry = libgit2_d.index.git_index_get_byindex(index, i);
				core.stdc.stdio.puts(entry.path);
			}

			return 0;
		}

		/* loop through the files found in the args and print them if they exist */
		for (size_t i = 0; i < opts.file_count; ++i) {
			const (char)* path = opts.files[i];
			entry = libgit2_d.index.git_index_get_bypath(index, path, libgit2_d.index.git_index_stage_t.GIT_INDEX_STAGE_NORMAL);

			if (entry != null) {
				core.stdc.stdio.puts(path);
			} else if (opts.error_unmatch) {
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "error: pathspec '%s' did not match any file(s) known to git.\n", path);
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "Did you forget to 'git add'?\n");

				return -1;
			}
		}

		return 0;
	}

extern (C)
nothrow @nogc
//int lg2_ls_files(libgit2_d.types.git_repository* repo, int argc, char*[] argv)
public int lg2_ls_files(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		.ls_options opts;
		int error = .parse_options(&opts, argc, argv);

		if (error < 0) {
			return error;
		}

		libgit2_d.types.git_index* index = null;

		scope (exit) {
			libgit2_d.index.git_index_free(index);
		}

		error = libgit2_d.repository.git_repository_index(&index, repo);

		if (error < 0) {
			return error;
		}

		error = .print_paths(&opts, index);

		return error;
	}
