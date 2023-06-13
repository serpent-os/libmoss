/*
 * libgit2 "describe" example - shows how to describe commits
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
module libgit2_d.example.describe;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.buffer;
private static import libgit2_d.describe;
private static import libgit2_d.example.args;
private static import libgit2_d.example.common;
private static import libgit2_d.revparse;
private static import libgit2_d.types;

package:

/**
 * The following example partially reimplements the `git describe` command
 * and some of its options.
 *
 * These commands should work:
 *
 * - Describe HEAD with default options (`describe`)
 * - Describe specified revision (`describe master~2`)
 * - Describe specified revisions (`describe master~2 HEAD~3`)
 * - Describe HEAD with dirty state suffix (`describe --dirty=*`)
 * - Describe consider all refs (`describe --all master`)
 * - Describe consider lightweight tags (`describe --tags temp-tag`)
 * - Describe show non-default abbreviated size (`describe --abbrev=10`)
 * - Describe always output the long format if matches a tag (`describe --long v1.0`)
 * - Describe consider only tags of specified pattern (`describe --match v*-release`)
 * - Describe show the fallback result (`describe --always`)
 * - Describe follow only the first parent commit (`describe --first-parent`)
 *
 * The command line parsing logic is simplified and doesn't handle
 * all of the use cases.
 */

/**
 * describe_options represents the parsed command line options
 */
public struct describe_options
{
	const (char)** commits;
	size_t commit_count;
	libgit2_d.describe.git_describe_options describe_options;
	libgit2_d.describe.git_describe_format_options format_options;
}

nothrow @nogc
private void opts_add_commit(.describe_options* opts, const (char)* commit)

	in
	{
		assert(opts != null);
	}

	do
	{
		size_t sz = ++opts.commit_count * opts.commits[0].sizeof;
		opts.commits = cast(const (char)**)(libgit2_d.example.common.xrealloc(cast(void*)(opts.commits), sz));
		opts.commits[opts.commit_count - 1] = commit;
	}

nothrow @nogc
private void do_describe_single(libgit2_d.types.git_repository* repo, .describe_options* opts, const (char)* rev)

	in
	{
	}

	do
	{
		libgit2_d.types.git_object* commit;
		libgit2_d.describe.git_describe_result* describe_result;

		if (rev != null) {
			libgit2_d.example.common.check_lg2(libgit2_d.revparse.git_revparse_single(&commit, repo, rev), "Failed to lookup rev", rev);

			libgit2_d.example.common.check_lg2(libgit2_d.describe.git_describe_commit(&describe_result, commit, &opts.describe_options), "Failed to describe rev", rev);
		} else {
			libgit2_d.example.common.check_lg2(libgit2_d.describe.git_describe_workdir(&describe_result, repo, &opts.describe_options), "Failed to describe workdir", null);
		}

		libgit2_d.buffer.git_buf buf = libgit2_d.buffer.git_buf.init;
		libgit2_d.example.common.check_lg2(libgit2_d.describe.git_describe_format(&buf, describe_result, &opts.format_options), "Failed to format describe rev", rev);

		core.stdc.stdio.printf("%s\n", buf.ptr_);
	}

nothrow @nogc
private void do_describe(libgit2_d.types.git_repository* repo, .describe_options* opts)

	in
	{
	}

	do
	{
		if (opts.commit_count == 0) {
			.do_describe_single(repo, opts, null);
		} else {
			for (size_t i = 0; i < opts.commit_count; i++) {
				.do_describe_single(repo, opts, opts.commits[i]);
			}
		}
	}

nothrow @nogc
private void print_usage()

	in
	{
	}

	do
	{
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: see `git help describe`\n");
		core.stdc.stdlib.exit(1);
	}

/**
 * Parse command line arguments
 */
nothrow @nogc
private void parse_options(.describe_options* opts, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);

		for (args.pos = 1; args.pos < argc; ++args.pos) {
			const (char)* curr = argv[args.pos];

			if (curr[0] != '-') {
				.opts_add_commit(opts, curr);
			} else if (!core.stdc.string.strcmp(curr, "--all")) {
				opts.describe_options.describe_strategy = libgit2_d.describe.git_describe_strategy_t.GIT_DESCRIBE_ALL;
			} else if (!core.stdc.string.strcmp(curr, "--tags")) {
				opts.describe_options.describe_strategy = libgit2_d.describe.git_describe_strategy_t.GIT_DESCRIBE_TAGS;
			} else if (!core.stdc.string.strcmp(curr, "--exact-match")) {
				opts.describe_options.max_candidates_tags = 0;
			} else if (!core.stdc.string.strcmp(curr, "--long")) {
				opts.format_options.always_use_long_format = 1;
			} else if (!core.stdc.string.strcmp(curr, "--always")) {
				opts.describe_options.show_commit_oid_as_fallback = 1;
			} else if (!core.stdc.string.strcmp(curr, "--first-parent")) {
				opts.describe_options.only_follow_first_parent = 1;
			} else if (libgit2_d.example.args.optional_str_arg(&opts.format_options.dirty_suffix, &args, "--dirty", "-dirty")) {
			} else if (libgit2_d.example.args.match_int_arg(cast(int*)(&opts.format_options.abbreviated_size), &args, "--abbrev", 0)) {
			} else if (libgit2_d.example.args.match_int_arg(cast(int*)(&opts.describe_options.max_candidates_tags), &args, "--candidates", 0)) {
			} else if (libgit2_d.example.args.match_str_arg(&opts.describe_options.pattern, &args, "--match")) {
			} else {
				.print_usage();
			}
		}

		if (opts.commit_count > 0) {
			if (opts.format_options.dirty_suffix) {
				libgit2_d.example.common.fatal("--dirty is incompatible with commit-ishes", null);
			}
		} else {
			if ((!opts.format_options.dirty_suffix) || (!opts.format_options.dirty_suffix[0])) {
				.opts_add_commit(opts, "HEAD");
			}
		}
	}

/**
 * Initialize describe_options struct
 */
nothrow @nogc
private void describe_options_init(.describe_options* opts)

	in
	{
	}

	do
	{
		core.stdc.string.memset(opts, 0, (*opts).sizeof);

		opts.commits = null;
		opts.commit_count = 0;
		libgit2_d.describe.git_describe_options_init(&opts.describe_options, libgit2_d.describe.GIT_DESCRIBE_OPTIONS_VERSION);
		libgit2_d.describe.git_describe_format_options_init(&opts.format_options, libgit2_d.describe.GIT_DESCRIBE_FORMAT_OPTIONS_VERSION);
	}

extern (C)
nothrow @nogc
public int lg2_describe(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		.describe_options opts;

		.describe_options_init(&opts);
		.parse_options(&opts, argc, argv);

		.do_describe(repo, &opts);

		return 0;
	}
