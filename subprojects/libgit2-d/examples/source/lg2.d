module libgit2_d.example.lg2;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.errors;
private static import libgit2_d.example.add;
private static import libgit2_d.example.args;
private static import libgit2_d.example.blame;
private static import libgit2_d.example.cat_file;
private static import libgit2_d.example.checkout;
private static import libgit2_d.example.clone;
private static import libgit2_d.example.commit;
private static import libgit2_d.example.common;
private static import libgit2_d.example.config;
private static import libgit2_d.example.describe;
private static import libgit2_d.example.diff;
private static import libgit2_d.example.fetch;
private static import libgit2_d.example.for_each_ref;
private static import libgit2_d.example.general;
private static import libgit2_d.example.index_pack;
private static import libgit2_d.example.init;
private static import libgit2_d.example.log;
private static import libgit2_d.example.ls_files;
private static import libgit2_d.example.ls_remote;
private static import libgit2_d.example.merge;
private static import libgit2_d.example.push;
private static import libgit2_d.example.remote;
private static import libgit2_d.example.rev_list;
private static import libgit2_d.example.rev_parse;
private static import libgit2_d.example.show_index;
private static import libgit2_d.example.stash;
private static import libgit2_d.example.status;
private static import libgit2_d.example.tag;
private static import libgit2_d.global;
private static import libgit2_d.repository;
private static import libgit2_d.types;

package:

/* This part is not strictly libgit2-dependent, but you can use this
 * as a starting point for a git-like tool */

public alias git_command_fn = extern (C) nothrow @nogc int function(libgit2_d.types.git_repository*, int, char**);

public struct commands_t
{
	immutable (char)* name;
	.git_command_fn fn;
	char requires_repo;
}

public static immutable .commands_t[] commands =
[
	{"add".ptr, &libgit2_d.example.add.lg2_add, 1},
	{"blame".ptr, &libgit2_d.example.blame.lg2_blame, 1},
	{"cat-file".ptr, &libgit2_d.example.cat_file.lg2_cat_file, 1},
	{"checkout".ptr, &libgit2_d.example.checkout.lg2_checkout, 1},
	{"clone".ptr, &libgit2_d.example.clone.lg2_clone, 0},
	{"commit".ptr, &libgit2_d.example.commit.lg2_commit, 1},
	{"config".ptr, &libgit2_d.example.config.lg2_config, 1},
	{"describe".ptr, &libgit2_d.example.describe.lg2_describe, 1},
	{"diff".ptr, &libgit2_d.example.diff.lg2_diff, 1},
	{"fetch".ptr, &libgit2_d.example.fetch.lg2_fetch, 1},
	{"for-each-ref".ptr, &libgit2_d.example.for_each_ref.lg2_for_each_ref, 1},
	{"general".ptr, &libgit2_d.example.general.lg2_general, 0},
	{"index-pack".ptr, &libgit2_d.example.index_pack.lg2_index_pack, 1},
	{"init".ptr, &libgit2_d.example.init.lg2_init, 0},
	{"log".ptr, &libgit2_d.example.log.lg2_log, 1},
	{"ls-files".ptr, &libgit2_d.example.ls_files.lg2_ls_files, 1},
	{"ls-remote".ptr, &libgit2_d.example.ls_remote.lg2_ls_remote, 1},
	{"merge".ptr, &libgit2_d.example.merge.lg2_merge, 1},
	{"push".ptr, &libgit2_d.example.push.lg2_push, 1},
	{"remote".ptr, &libgit2_d.example.remote.lg2_remote, 1},
	{"rev-list".ptr, &libgit2_d.example.rev_list.lg2_rev_list, 1},
	{"rev-parse".ptr, &libgit2_d.example.rev_parse.lg2_rev_parse, 1},
	{"show-index".ptr, &libgit2_d.example.show_index.lg2_show_index, 0},
	{"stash".ptr, &libgit2_d.example.stash.lg2_stash, 1},
	{"status".ptr, &libgit2_d.example.status.lg2_status, 1},
	{"tag".ptr, &libgit2_d.example.tag.lg2_tag, 1},
];

nothrow @nogc
private int run_command(.git_command_fn fn, libgit2_d.types.git_repository* repo, libgit2_d.example.args.args_info args)

	in
	{
	}

	do
	{
		/* Run the command. If something goes wrong, print the error message to stderr */
		int error = fn(repo, args.argc - args.pos, &args.argv[args.pos]);

		if (error < 0) {
			if (libgit2_d.errors.git_error_last() == null) {
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "Error without message");
			} else {
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "Bad news:\n %s\n", libgit2_d.errors.git_error_last().message);
			}
		}

		return !!error;
	}

nothrow @nogc
private void usage(const (char)* prog)

	in
	{
	}

	do
	{
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: %s <cmd>...\n\nAvailable commands:\n\n", prog);

		for (size_t i = 0; i < commands.length; i++) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "\t%s\n", commands[i].name);
		}

		core.stdc.stdlib.exit(core.stdc.stdlib.EXIT_FAILURE);
	}

version (LIBGIT2_EXAMPLE) {
	extern (C)
	nothrow @nogc
	public int main(int argc, char** argv)

		do
		{
			if (argc < 2) {
				.usage(argv[0]);
			}

			libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);
			libgit2_d.global.git_libgit2_init();

			const (char)* git_dir = null;

			for (args.pos = 1; args.pos < args.argc; ++args.pos) {
				char* a = args.argv[args.pos];

				if (a[0] != '-') {
					/* non-arg */
					break;
				} else if (libgit2_d.example.args.optional_str_arg(&git_dir, &args, "--git-dir", ".git")) {
					continue;
				} else if (libgit2_d.example.args.match_arg_separator(&args)) {
					break;
				}
			}

			if (args.pos == args.argc) {
				.usage(argv[0]);
			}

			if (git_dir == null) {
				git_dir = ".";
			}

			libgit2_d.types.git_repository* repo = null;
			int return_code = 1;

			scope (exit) {
				libgit2_d.repository.git_repository_free(repo);
				libgit2_d.global.git_libgit2_shutdown();
			}

			for (size_t i = 0; i < commands.length; ++i) {
				if (core.stdc.string.strcmp(args.argv[args.pos], commands[i].name)) {
					continue;
				}

				/*
				 * Before running the actual command, create an instance
				 * of the local repository and pass it to the function.
				 */
				if (commands[i].requires_repo) {
					libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_open_ext(&repo, git_dir, 0, null), "Unable to open repository '%s'", git_dir);
				}

				return_code = run_command(commands[i].fn, repo, args);

				return return_code;
			}

			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "Command not found: %s\n", argv[1]);

			return return_code;
		}
}
