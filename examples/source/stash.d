/*
 * libgit2 "stash" example - shows how to use the stash API
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
module libgit2_d.example.stash;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.commit;
private static import libgit2_d.example.common;
private static import libgit2_d.oid;
private static import libgit2_d.signature;
private static import libgit2_d.stash;
private static import libgit2_d.types;

package:

enum subcmd
{
	SUBCMD_APPLY,
	SUBCMD_LIST,
	SUBCMD_POP,
	SUBCMD_PUSH,
}

//Declaration name in C language
enum
{
	SUBCMD_APPLY = .subcmd.SUBCMD_APPLY,
	SUBCMD_LIST = .subcmd.SUBCMD_LIST,
	SUBCMD_POP = .subcmd.SUBCMD_POP,
	SUBCMD_PUSH = .subcmd.SUBCMD_PUSH,
}

struct opts
{
	.subcmd cmd;
	int argc;
	char** argv;
}

nothrow @nogc
private void usage(const (char)* fmt, const char* msg = null)

	in
	{
	}

	do
	{
		core.stdc.stdio.fputs("usage: git stash list\n", core.stdc.stdio.stderr);
		core.stdc.stdio.fputs("   or: git stash ( pop | apply )\n", core.stdc.stdio.stderr);
		core.stdc.stdio.fputs("   or: git stash [push]\n", core.stdc.stdio.stderr);
		core.stdc.stdio.fputs("\n", core.stdc.stdio.stderr);

		if (msg == null) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, fmt);
		} else {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, fmt, msg);
		}

		core.stdc.stdlib.exit(1);
	}

nothrow @nogc
private void parse_subcommand(.opts* opts, int argc, char** argv)

	in
	{
	}

	do
	{
		const char* arg = (argc < 2) ? ("push") : (argv[1]);
		.subcmd cmd;

		if (!core.stdc.string.strcmp(arg, "apply")) {
			cmd = .subcmd.SUBCMD_APPLY;
		} else if (!core.stdc.string.strcmp(arg, "list")) {
			cmd = .subcmd.SUBCMD_LIST;
		} else if (!core.stdc.string.strcmp(arg, "pop")) {
			cmd = .subcmd.SUBCMD_POP;
		} else if (!core.stdc.string.strcmp(arg, "push")) {
			cmd = .subcmd.SUBCMD_PUSH;
		} else {
			.usage("invalid command %s", arg);

			return;
		}

		opts.cmd = cmd;
		opts.argc = (argc < 2) ? (argc - 1) : (argc - 2);
		opts.argv = argv;
	}

nothrow @nogc
private int cmd_apply(libgit2_d.types.git_repository* repo, .opts* opts)

	in
	{
	}

	do
	{
		if (opts.argc) {
			.usage("apply does not accept any parameters");
		}

		libgit2_d.example.common.check_lg2(libgit2_d.stash.git_stash_apply(repo, 0, null), "Unable to apply stash", null);

		return 0;
	}

extern (C)
nothrow @nogc
private int list_stash_cb(size_t index, const (char)* message, const (libgit2_d.oid.git_oid)* stash_id, void* payload)

	in
	{
	}

	do
	{
		//cast(void)(stash_id);
		//cast(void)(payload);
		core.stdc.stdio.printf("stash@{%" ~ libgit2_d.example.common.PRIuZ ~ "}: %s\n", index, message);

		return 0;
	}

nothrow @nogc
private int cmd_list(libgit2_d.types.git_repository* repo, .opts* opts)

	in
	{
	}

	do
	{
		if (opts.argc) {
			.usage("list does not accept any parameters");
		}

		libgit2_d.example.common.check_lg2(libgit2_d.stash.git_stash_foreach(repo, &.list_stash_cb, null), "Unable to list stashes", null);

		return 0;
	}

nothrow @nogc
private int cmd_push(libgit2_d.types.git_repository* repo, .opts* opts)

	in
	{
	}

	do
	{
		if (opts.argc) {
			.usage("push does not accept any parameters");
		}

		libgit2_d.types.git_signature* signature;
		libgit2_d.example.common.check_lg2(libgit2_d.signature.git_signature_default(&signature, repo), "Unable to get signature", null);

		libgit2_d.oid.git_oid stashid;
		libgit2_d.example.common.check_lg2(libgit2_d.stash.git_stash_save(&stashid, repo, signature, null, libgit2_d.stash.git_stash_flags.GIT_STASH_DEFAULT), "Unable to save stash", null);

		libgit2_d.types.git_commit* stash;
		libgit2_d.example.common.check_lg2(libgit2_d.commit.git_commit_lookup(&stash, repo, &stashid), "Unable to lookup stash commit", null);

		core.stdc.stdio.printf("Saved working directory %s\n", libgit2_d.commit.git_commit_summary(stash));

		libgit2_d.signature.git_signature_free(signature);
		libgit2_d.commit.git_commit_free(stash);

		return 0;
	}

nothrow @nogc
private int cmd_pop(libgit2_d.types.git_repository* repo, .opts* opts)

	in
	{
	}

	do
	{
		if (opts.argc) {
			.usage("pop does not accept any parameters");
		}

		libgit2_d.example.common.check_lg2(libgit2_d.stash.git_stash_pop(repo, 0, null), "Unable to pop stash", null);

		core.stdc.stdio.printf("Dropped refs/stash@{0}\n");

		return 0;
	}

extern (C)
nothrow @nogc
//int lg2_stash(libgit2_d.types.git_repository* repo, int argc, char*[] argv)
public int lg2_stash(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		.opts opts = .opts.init;

		.parse_subcommand(&opts, argc, argv);

		switch (opts.cmd) {
			case .subcmd.SUBCMD_APPLY:
				return .cmd_apply(repo, &opts);

			case .subcmd.SUBCMD_LIST:
				return .cmd_list(repo, &opts);

			case .subcmd.SUBCMD_PUSH:
				return .cmd_push(repo, &opts);

			case .subcmd.SUBCMD_POP:
				return .cmd_pop(repo, &opts);

			default:
				break;
		}

		return -1;
	}
