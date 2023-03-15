/*
 * libgit2 "remote" example - shows how to modify remotes for a repo
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
module libgit2_d.example.remote;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.example.common;
private static import libgit2_d.remote;
private static import libgit2_d.strarray;
private static import libgit2_d.types;

package:

/**
 * This is a sample program that is similar to "git remote".  See the
 * documentation for that (try "git help remote") to understand what this
 * program is emulating.
 *
 * This demonstrates using the libgit2 APIs to modify remotes of a repository.
 */

public enum subcmd
{
	subcmd_add,
	subcmd_remove,
	subcmd_rename,
	subcmd_seturl,
	subcmd_show,
}

//Declaration name in C language
public enum
{
	subcmd_add = .subcmd.subcmd_add,
	subcmd_remove = .subcmd.subcmd_remove,
	subcmd_rename = .subcmd.subcmd_rename,
	subcmd_seturl = .subcmd.subcmd_seturl,
	subcmd_show = .subcmd.subcmd_show,
}

public struct remote_opts
{
	.subcmd cmd;

	/* for command-specific args */
	int argc;
	char** argv;
}

extern (C)
nothrow @nogc
//int lg2_remote(libgit2_d.types.git_repository* repo, int argc, char*[] argv)
public int lg2_remote(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		int retval = 0;
		.remote_opts opt = .remote_opts.init;

		.parse_subcmd(&opt, argc, argv);

		switch (opt.cmd) {
			case .subcmd.subcmd_add:
				retval = .cmd_add(repo, &opt);

				break;

			case .subcmd.subcmd_remove:
				retval = .cmd_remove(repo, &opt);

				break;

			case .subcmd.subcmd_rename:
				retval = .cmd_rename(repo, &opt);

				break;

			case .subcmd.subcmd_seturl:
				retval = .cmd_seturl(repo, &opt);

				break;

			case .subcmd.subcmd_show:
				retval = .cmd_show(repo, &opt);

				break;

			default:
				break;
		}

		return retval;
	}

nothrow @nogc
private int cmd_add(libgit2_d.types.git_repository* repo, .remote_opts* o)

	in
	{
	}

	do
	{
		libgit2_d.types.git_remote* remote = null;

		if (o.argc != 2) {
			.usage("you need to specify a name and URL", null);
		}

		char* name = o.argv[0];
		char* url = o.argv[1];

		libgit2_d.example.common.check_lg2(libgit2_d.remote.git_remote_create(&remote, repo, name, url), "could not create remote", null);

		return 0;
	}

nothrow @nogc
private int cmd_remove(libgit2_d.types.git_repository* repo, .remote_opts* o)

	in
	{
	}

	do
	{
		if (o.argc != 1) {
			.usage("you need to specify a name", null);
		}

		char* name = o.argv[0];

		libgit2_d.example.common.check_lg2(libgit2_d.remote.git_remote_delete(repo, name), "could not delete remote", name);

		return 0;
	}

nothrow @nogc
private int cmd_rename(libgit2_d.types.git_repository* repo, .remote_opts* o)

	in
	{
	}

	do
	{
		libgit2_d.strarray.git_strarray problems = libgit2_d.strarray.git_strarray.init;

		if (o.argc != 2) {
			.usage("you need to specify old and new remote name", null);
		}

		char* old = o.argv[0];
		char* new_ = o.argv[1];

		int retval = libgit2_d.remote.git_remote_rename(&problems, repo, old, new_);

		if (!retval) {
			return 0;
		}

		for (int i = 0; i < cast(int)(problems.count); i++) {
			core.stdc.stdio.puts(problems.strings[0]);
		}

		libgit2_d.strarray.git_strarray_dispose(&problems);

		return retval;
	}

nothrow @nogc
private int cmd_seturl(libgit2_d.types.git_repository* repo, .remote_opts* o)

	in
	{
	}

	do
	{
		int push = 0;
		char* name = null;
		char* url = null;

		for (int i = 0; i < o.argc; i++) {
			char* arg = o.argv[i];

			if (!core.stdc.string.strcmp(arg, "--push")) {
				push = 1;
			} else if ((arg[0] != '-') && (name == null)) {
				name = arg;
			} else if ((arg[0] != '-') && (url == null)) {
				url = arg;
			} else {
				.usage("invalid argument to set-url", arg);
			}
		}

		if ((name == null) || (url == null)) {
			.usage("you need to specify remote and the new URL", null);
		}

		int retval;

		if (push) {
			retval = libgit2_d.remote.git_remote_set_pushurl(repo, name, url);
		} else {
			retval = libgit2_d.remote.git_remote_set_url(repo, name, url);
		}

		libgit2_d.example.common.check_lg2(retval, "could not set URL", url);

		return 0;
	}

nothrow @nogc
private int cmd_show(libgit2_d.types.git_repository* repo, .remote_opts* o)

	in
	{
	}

	do
	{
		int verbose = 0;
		libgit2_d.strarray.git_strarray remotes = libgit2_d.strarray.git_strarray.init;
		libgit2_d.types.git_remote* remote = null;

		for (int i = 0; i < o.argc; i++) {
			const (char)* arg = o.argv[i];

			if ((!core.stdc.string.strcmp(arg, "-v")) || (!core.stdc.string.strcmp(arg, "--verbose"))) {
				verbose = 1;
			}
		}

		libgit2_d.example.common.check_lg2(libgit2_d.remote.git_remote_list(&remotes, repo), "could not retrieve remotes", null);

		for (int i = 0; i < cast(int)(remotes.count); i++) {
			const (char)* name = remotes.strings[i];

			if (!verbose) {
				core.stdc.stdio.puts(name);

				continue;
			}

			libgit2_d.example.common.check_lg2(libgit2_d.remote.git_remote_lookup(&remote, repo, name), "could not look up remote", name);

			const (char)* fetch = libgit2_d.remote.git_remote_url(remote);

			if (fetch != null) {
				core.stdc.stdio.printf("%s\t%s (fetch)\n", name, fetch);
			}

			const (char)* push = libgit2_d.remote.git_remote_pushurl(remote);

			/* use fetch URL if no distinct push URL has been set */
			push = (push != null) ? (push) : (fetch);

			if (push != null) {
				core.stdc.stdio.printf("%s\t%s (push)\n", name, push);
			}

			libgit2_d.remote.git_remote_free(remote);
		}

		libgit2_d.strarray.git_strarray_dispose(&remotes);

		return 0;
	}

nothrow @nogc
private void parse_subcmd(.remote_opts* opt, int argc, char** argv)

	in
	{
	}

	do
	{
		char* arg = argv[1];
		.subcmd cmd = cast(.subcmd)(0);

		if (argc < 2) {
			.usage("no command specified", null);
		}

		if (!core.stdc.string.strcmp(arg, "add")) {
			cmd = .subcmd.subcmd_add;
		} else if (!core.stdc.string.strcmp(arg, "remove")) {
			cmd = .subcmd.subcmd_remove;
		} else if (!core.stdc.string.strcmp(arg, "rename")) {
			cmd = .subcmd.subcmd_rename;
		} else if (!core.stdc.string.strcmp(arg, "set-url")) {
			cmd = .subcmd.subcmd_seturl;
		} else if (!core.stdc.string.strcmp(arg, "show")) {
			cmd = .subcmd.subcmd_show;
		} else {
			.usage("command is not valid", arg);
		}

		opt.cmd = cmd;

		/* executable and subcommand are removed */
		opt.argc = argc - 2;

		opt.argv = argv + 2;
	}

nothrow @nogc
private void usage(const (char)* msg, const (char)* arg)

	in
	{
	}

	do
	{
		core.stdc.stdio.fputs("usage: remote add <name> <url>\n", core.stdc.stdio.stderr);
		core.stdc.stdio.fputs("       remote remove <name>\n", core.stdc.stdio.stderr);
		core.stdc.stdio.fputs("       remote rename <old> <new>\n", core.stdc.stdio.stderr);
		core.stdc.stdio.fputs("       remote set-url [--push] <name> <newurl>\n", core.stdc.stdio.stderr);
		core.stdc.stdio.fputs("       remote show [-v|--verbose]\n", core.stdc.stdio.stderr);

		if ((msg != null) && (arg == null)) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "\n%s\n", msg);
		} else if ((msg != null) && (arg != null)) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "\n%s: %s\n", msg, arg);
		}

		core.stdc.stdlib.exit(1);
	}
