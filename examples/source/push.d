/*
 * libgit2 "push" example - shows how to push to remote
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
/**
 * This example demonstrates the libgit2 push API to roughly
 * simulate `git push`.
 *
 * This does not have:
 *
 * - Robust error handling
 * - Any of the `git push` options
 *
 * This does have:
 *
 * - Example of push to origin/master
 *
 */
module libgit2_d.example.push;


private static import core.stdc.stdio;
private static import libgit2_d.example.common;
private static import libgit2_d.remote;
private static import libgit2_d.strarray;
private static import libgit2_d.types;

package:

/**
 * Entry point for this command
 */
extern (C)
nothrow @nogc
public int lg2_push(libgit2_d.types.git_repository* repo, int argc, char** argv)

	do
	{
		/* Validate args */
		if (argc > 1) {
			core.stdc.stdio.printf("USAGE: %s\n\nsorry, no arguments supported yet\n", argv[0]);

			return -1;
		}

		libgit2_d.types.git_remote* remote = null;
		libgit2_d.example.common.check_lg2(libgit2_d.remote.git_remote_lookup(&remote, repo, "origin"), "Unable to lookup remote", null);

		libgit2_d.remote.git_push_options options;
		libgit2_d.example.common.check_lg2(libgit2_d.remote.git_push_options_init(&options, libgit2_d.remote.GIT_PUSH_OPTIONS_VERSION), "Error initializing push", null);

		const (char)* refspec = "refs/heads/master";
		const libgit2_d.strarray.git_strarray refspecs = {&refspec, 1};
		libgit2_d.example.common.check_lg2(libgit2_d.remote.git_remote_push(remote, &refspecs, &options), "Error pushing", null);

		core.stdc.stdio.printf("pushed\n");

		return 0;
	}
