/*
 * libgit2 "diff" example - shows how to use the diff API
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
module libgit2_d.example.diff;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.buffer;
private static import libgit2_d.diff;
private static import libgit2_d.example.args;
private static import libgit2_d.example.common;
private static import libgit2_d.patch;
private static import libgit2_d.tree;
private static import libgit2_d.types;

package:

/**
 * This example demonstrates the use of the libgit2 diff APIs to
 * create `libgit2_d.diff.git_diff` objects and display them, emulating a number of
 * core Git `diff` command line options.
 *
 * This covers on a portion of the core Git diff options and doesn't
 * have particularly good error handling, but it should show most of
 * the core libgit2 diff APIs, including various types of diffs and
 * how to do renaming detection and patch formatting.
 */

private const (char)*[] colors =
[
	"\033[m", /* reset */
	"\033[1m", /* bold */
	"\033[31m", /* red */
	"\033[32m", /* green */
	"\033[36m", /* cyan */
];

public enum
{
	OUTPUT_DIFF = 1 << 0,
	OUTPUT_STAT = 1 << 1,
	OUTPUT_SHORTSTAT = 1 << 2,
	OUTPUT_NUMSTAT = 1 << 3,
	OUTPUT_SUMMARY = 1 << 4,
}

public enum
{
	CACHE_NORMAL = 0,
	CACHE_ONLY = 1,
	CACHE_NONE = 2,
}

/**
 * The 'diff_options' struct captures all the various parsed command line options.
 */
public struct diff_options
{
	libgit2_d.diff.git_diff_options diffopts;
	libgit2_d.diff.git_diff_find_options findopts;
	int color;
	int no_index;
	int cache;
	int output;
	libgit2_d.diff.git_diff_format_t format = cast(libgit2_d.diff.git_diff_format_t)(0);
	const (char)* treeish1;
	const (char)* treeish2;
	const (char)* dir;
}

/** These functions are implemented at the end */
//private void usage(const (char)* message, const (char)* arg);
//private void parse_opts(.diff_options* o, int argc, char*[] argv);
//private int color_printer(const (libgit2_d.diff.git_diff_delta)*, const (libgit2_d.diff.git_diff_hunk)*, const (libgit2_d.diff.git_diff_line)*, void*);
//private void diff_print_stats(libgit2_d.diff.git_diff* diff, .diff_options* o);
//private void compute_diff_no_index(libgit2_d.diff.git_diff** diff, .diff_options* o);

extern (C)
nothrow @nogc
//int lg2_diff(libgit2_d.types.git_repository* repo, int argc, char*[] argv)
public int lg2_diff(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.types.git_tree* t1 = null;
		libgit2_d.types.git_tree* t2 = null;
		libgit2_d.diff.git_diff* diff;

		.diff_options o = {libgit2_d.diff.GIT_DIFF_OPTIONS_INIT(), libgit2_d.diff.GIT_DIFF_FIND_OPTIONS_INIT(), -1, -1, 0, 0, libgit2_d.diff.git_diff_format_t.GIT_DIFF_FORMAT_PATCH, null, null, "."};

		.parse_opts(&o, argc, argv);

		/**
		 * Possible argument patterns:
		 *
		 *  * &lt;sha1&gt; &lt;sha2&gt;
		 *  * &lt;sha1&gt; --cached
		 *  * &lt;sha1&gt;
		 *  * --cached
		 *  * --nocache (don't use index data in diff at all)
		 *  * --no-index &lt;file1&gt; &lt;file2&gt;
		 *  * nothing
		 *
		 * Currently ranged arguments like &lt;sha1&gt;..&lt;sha2&gt; and &lt;sha1&gt;...&lt;sha2&gt;
		 * are not supported in this example
		 */

		if (o.no_index >= 0) {
			.compute_diff_no_index(&diff, &o);
		} else {
			if (o.treeish1 != null) {
				libgit2_d.example.common.treeish_to_tree(&t1, repo, o.treeish1);
			}

			if (o.treeish2 != null) {
				libgit2_d.example.common.treeish_to_tree(&t2, repo, o.treeish2);
			}

			if ((t1 != null) && (t2 != null)) {
				libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_tree_to_tree(&diff, repo, t1, t2, &o.diffopts), "diff trees", null);
			} else if (o.cache != .CACHE_NORMAL) {
				if (t1 == null) {
					libgit2_d.example.common.treeish_to_tree(&t1, repo, "HEAD");
				}

				if (o.cache == .CACHE_NONE) {
					libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_tree_to_workdir(&diff, repo, t1, &o.diffopts), "diff tree to working directory", null);
				} else {
					libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_tree_to_index(&diff, repo, t1, null, &o.diffopts), "diff tree to index", null);
				}
			} else if (t1 != null) {
				libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_tree_to_workdir_with_index(&diff, repo, t1, &o.diffopts), "diff tree to working directory", null);
			} else {
				libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_index_to_workdir(&diff, repo, null, &o.diffopts), "diff index to working directory", null);
			}

			/** Apply rename and copy detection if requested. */

			if ((o.findopts.flags & libgit2_d.diff.git_diff_find_t.GIT_DIFF_FIND_ALL) != 0) {
				libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_find_similar(diff, &o.findopts), "finding renames and copies", null);
			}
		}

		/** Generate simple output using libgit2 display helper. */

		if (!o.output) {
			o.output = .OUTPUT_DIFF;
		}

		if (o.output != .OUTPUT_DIFF) {
			.diff_print_stats(diff, &o);
		}

		if ((o.output & .OUTPUT_DIFF) != 0) {
			if (o.color >= 0) {
				core.stdc.stdio.fputs(.colors[0], core.stdc.stdio.stdout);
			}

			libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_print(diff, o.format, &.color_printer, &o.color), "displaying diff", null);

			if (o.color >= 0) {
				core.stdc.stdio.fputs(.colors[0], core.stdc.stdio.stdout);
			}
		}

		/** Cleanup before exiting. */
		libgit2_d.diff.git_diff_free(diff);
		libgit2_d.tree.git_tree_free(t1);
		libgit2_d.tree.git_tree_free(t2);

		return 0;
	}

nothrow @nogc
private void compute_diff_no_index(libgit2_d.diff.git_diff** diff, .diff_options* o)

	in
	{
	}

	do
	{
		if ((!o.treeish1) || (!o.treeish2)) {
			.usage("two files should be provided as arguments", null);
		}

		char* file1_str = libgit2_d.example.common.read_file(o.treeish1);

		if (file1_str == null) {
			.usage("file cannot be read", o.treeish1);
		}

		char* file2_str = libgit2_d.example.common.read_file(o.treeish2);

		if (file2_str == null) {
			.usage("file cannot be read", o.treeish2);
		}

		libgit2_d.patch.git_patch* patch = null;
		libgit2_d.example.common.check_lg2(libgit2_d.patch.git_patch_from_buffers(&patch, file1_str, core.stdc.string.strlen(file1_str), o.treeish1, file2_str, core.stdc.string.strlen(file2_str), o.treeish2, &o.diffopts), "patch buffers", null);
		libgit2_d.buffer.git_buf buf = libgit2_d.buffer.git_buf.init;
		libgit2_d.example.common.check_lg2(libgit2_d.patch.git_patch_to_buf(&buf, patch), "patch to buf", null);
		libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_from_buffer(diff, buf.ptr_, buf.size), "diff from patch", null);
		libgit2_d.patch.git_patch_free(patch);
		libgit2_d.buffer.git_buf_dispose(&buf);
		core.stdc.stdlib.free(file1_str);
		core.stdc.stdlib.free(file2_str);
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

		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: diff [<tree-oid> [<tree-oid>]]\n");
		core.stdc.stdlib.exit(1);
	}

/**
 * This implements very rudimentary colorized output.
 */
extern (C)
nothrow @nogc
private int color_printer(const (libgit2_d.diff.git_diff_delta)* delta, const (libgit2_d.diff.git_diff_hunk)* hunk, const (libgit2_d.diff.git_diff_line)* line, void* data)

	in
	{
	}

	do
	{
		int* last_color = cast(int*)(data);
		int color = 0;

		//cast(void)(delta);
		//cast(void)(hunk);

		if (*last_color >= 0) {
			switch (line.origin) {
				case libgit2_d.diff.git_diff_line_t.GIT_DIFF_LINE_ADDITION:
					color = 3;

					break;

				case libgit2_d.diff.git_diff_line_t.GIT_DIFF_LINE_DELETION:
					color = 2;

					break;

				case libgit2_d.diff.git_diff_line_t.GIT_DIFF_LINE_ADD_EOFNL:
					color = 3;

					break;

				case libgit2_d.diff.git_diff_line_t.GIT_DIFF_LINE_DEL_EOFNL:
					color = 2;

					break;

				case libgit2_d.diff.git_diff_line_t.GIT_DIFF_LINE_FILE_HDR:
					color = 1;

					break;

				case libgit2_d.diff.git_diff_line_t.GIT_DIFF_LINE_HUNK_HDR:
					color = 4;

					break;

				default:
					break;
			}

			if (color != *last_color) {
				if ((*last_color == 1) || (color == 1)) {
					core.stdc.stdio.fputs(.colors[0], core.stdc.stdio.stdout);
				}

				core.stdc.stdio.fputs(.colors[color], core.stdc.stdio.stdout);
				*last_color = color;
			}
		}

		return libgit2_d.example.common.diff_output(delta, hunk, line, cast(void*)(core.stdc.stdio.stdout));
	}

/**
 * Parse arguments as copied from git-diff.
 */
nothrow @nogc
private void parse_opts(.diff_options* o, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);

		for (args.pos = 1; args.pos < argc; ++args.pos) {
			const (char)* a = argv[args.pos];

			if (a[0] != '-') {
				if (o.treeish1 == null) {
					o.treeish1 = a;
				} else if (o.treeish2 == null) {
					o.treeish2 = a;
				} else {
					.usage("Only one or two tree identifiers can be provided", null);
				}
			} else if ((!core.stdc.string.strcmp(a, "-p")) || (!core.stdc.string.strcmp(a, "-u")) || (!core.stdc.string.strcmp(a, "--patch"))) {
				o.output |= .OUTPUT_DIFF;
				o.format = libgit2_d.diff.git_diff_format_t.GIT_DIFF_FORMAT_PATCH;
			} else if (!core.stdc.string.strcmp(a, "--cached")) {
				o.cache = .CACHE_ONLY;

				if (o.no_index >= 0) {
					.usage("--cached and --no-index are incompatible", null);
				}
			} else if (!core.stdc.string.strcmp(a, "--nocache")) {
				o.cache = .CACHE_NONE;
			} else if ((!core.stdc.string.strcmp(a, "--name-only")) || (!core.stdc.string.strcmp(a, "--format=name"))) {
				o.format = libgit2_d.diff.git_diff_format_t.GIT_DIFF_FORMAT_NAME_ONLY;
			} else if ((!core.stdc.string.strcmp(a, "--name-status")) || (!core.stdc.string.strcmp(a, "--format=name-status"))) {
				o.format = libgit2_d.diff.git_diff_format_t.GIT_DIFF_FORMAT_NAME_STATUS;
			} else if ((!core.stdc.string.strcmp(a, "--raw")) || (!core.stdc.string.strcmp(a, "--format=raw"))) {
				o.format = libgit2_d.diff.git_diff_format_t.GIT_DIFF_FORMAT_RAW;
			} else if (!core.stdc.string.strcmp(a, "--format=diff-index")) {
				o.format = libgit2_d.diff.git_diff_format_t.GIT_DIFF_FORMAT_RAW;
				o.diffopts.id_abbrev = 40;
			} else if (!core.stdc.string.strcmp(a, "--no-index")) {
				o.no_index = 0;

				if (o.cache == .CACHE_ONLY) {
					.usage("--cached and --no-index are incompatible", null);
				}
			} else if (!core.stdc.string.strcmp(a, "--color")) {
				o.color = 0;
			} else if (!core.stdc.string.strcmp(a, "--no-color")) {
				o.color = -1;
			} else if (!core.stdc.string.strcmp(a, "-R")) {
				o.diffopts.flags |= libgit2_d.diff.git_diff_option_t.GIT_DIFF_REVERSE;
			} else if ((!core.stdc.string.strcmp(a, "-a")) || (!core.stdc.string.strcmp(a, "--text"))) {
				o.diffopts.flags |= libgit2_d.diff.git_diff_option_t.GIT_DIFF_FORCE_TEXT;
			} else if (!core.stdc.string.strcmp(a, "--ignore-space-at-eol")) {
				o.diffopts.flags |= libgit2_d.diff.git_diff_option_t.GIT_DIFF_IGNORE_WHITESPACE_EOL;
			} else if ((!core.stdc.string.strcmp(a, "-b")) || (!core.stdc.string.strcmp(a, "--ignore-space-change"))) {
				o.diffopts.flags |= libgit2_d.diff.git_diff_option_t.GIT_DIFF_IGNORE_WHITESPACE_CHANGE;
			} else if ((!core.stdc.string.strcmp(a, "-w")) || (!core.stdc.string.strcmp(a, "--ignore-all-space"))) {
				o.diffopts.flags |= libgit2_d.diff.git_diff_option_t.GIT_DIFF_IGNORE_WHITESPACE;
			} else if (!core.stdc.string.strcmp(a, "--ignored")) {
				o.diffopts.flags |= libgit2_d.diff.git_diff_option_t.GIT_DIFF_INCLUDE_IGNORED;
			} else if (!core.stdc.string.strcmp(a, "--untracked")) {
				o.diffopts.flags |= libgit2_d.diff.git_diff_option_t.GIT_DIFF_INCLUDE_UNTRACKED;
			} else if (!core.stdc.string.strcmp(a, "--patience")) {
				o.diffopts.flags |= libgit2_d.diff.git_diff_option_t.GIT_DIFF_PATIENCE;
			} else if (!core.stdc.string.strcmp(a, "--minimal")) {
				o.diffopts.flags |= libgit2_d.diff.git_diff_option_t.GIT_DIFF_MINIMAL;
			} else if (!core.stdc.string.strcmp(a, "--stat")) {
				o.output |= .OUTPUT_STAT;
			} else if (!core.stdc.string.strcmp(a, "--numstat")) {
				o.output |= .OUTPUT_NUMSTAT;
			} else if (!core.stdc.string.strcmp(a, "--shortstat")) {
				o.output |= .OUTPUT_SHORTSTAT;
			} else if (!core.stdc.string.strcmp(a, "--summary")) {
				o.output |= .OUTPUT_SUMMARY;
			} else if (libgit2_d.example.args.match_uint16_arg(&o.findopts.rename_threshold, &args, "-M") || libgit2_d.example.args.match_uint16_arg(&o.findopts.rename_threshold, &args, "--find-renames")) {
				o.findopts.flags |= libgit2_d.diff.git_diff_find_t.GIT_DIFF_FIND_RENAMES;
			} else if (libgit2_d.example.args.match_uint16_arg(&o.findopts.copy_threshold, &args, "-C") || libgit2_d.example.args.match_uint16_arg(&o.findopts.copy_threshold, &args, "--find-copies")) {
				o.findopts.flags |= libgit2_d.diff.git_diff_find_t.GIT_DIFF_FIND_COPIES;
			} else if (!core.stdc.string.strcmp(a, "--find-copies-harder")) {
				o.findopts.flags |= libgit2_d.diff.git_diff_find_t.GIT_DIFF_FIND_COPIES_FROM_UNMODIFIED;
			} else if (libgit2_d.example.args.is_prefixed(a, "-B") || libgit2_d.example.args.is_prefixed(a, "--break-rewrites")) {
				/* TODO: parse thresholds */
				o.findopts.flags |= libgit2_d.diff.git_diff_find_t.GIT_DIFF_FIND_REWRITES;
			} else if ((!libgit2_d.example.args.match_uint32_arg(&o.diffopts.context_lines, &args, "-U")) && (!libgit2_d.example.args.match_uint32_arg(&o.diffopts.context_lines, &args, "--unified")) && (!libgit2_d.example.args.match_uint32_arg(&o.diffopts.interhunk_lines, &args, "--inter-hunk-context")) && !libgit2_d.example.args.match_uint16_arg(&o.diffopts.id_abbrev, &args, "--abbrev") && !libgit2_d.example.args.match_str_arg(&o.diffopts.old_prefix, &args, "--src-prefix") && (!libgit2_d.example.args.match_str_arg(&o.diffopts.new_prefix, &args, "--dst-prefix")) && (!libgit2_d.example.args.match_str_arg(&o.dir, &args, "--git-dir"))) {
				.usage("Unknown command line argument", a);
			}
		}
	}

/**
 * Display diff output with "--stat", "--numstat", or "--shortstat"
 */
nothrow @nogc
private void diff_print_stats(libgit2_d.diff.git_diff* diff, .diff_options* o)

	in
	{
	}

	do
	{
		libgit2_d.diff.git_diff_stats* stats;
		libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_get_stats(&stats, diff), "generating stats for diff", null);

		libgit2_d.diff.git_diff_stats_format_t format = libgit2_d.diff.git_diff_stats_format_t.GIT_DIFF_STATS_NONE;

		if (o.output & .OUTPUT_STAT) {
			format |= libgit2_d.diff.git_diff_stats_format_t.GIT_DIFF_STATS_FULL;
		}

		if (o.output & .OUTPUT_SHORTSTAT) {
			format |= libgit2_d.diff.git_diff_stats_format_t.GIT_DIFF_STATS_SHORT;
		}

		if (o.output & .OUTPUT_NUMSTAT) {
			format |= libgit2_d.diff.git_diff_stats_format_t.GIT_DIFF_STATS_NUMBER;
		}

		if (o.output & .OUTPUT_SUMMARY) {
			format |= libgit2_d.diff.git_diff_stats_format_t.GIT_DIFF_STATS_INCLUDE_SUMMARY;
		}

		libgit2_d.buffer.git_buf b;
		libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_stats_to_buf(&b, stats, format, 80), "formatting stats", null);

		b = libgit2_d.buffer.GIT_BUF_INIT_CONST(null, 0);
		core.stdc.stdio.fputs(b.ptr_, core.stdc.stdio.stdout);

		libgit2_d.buffer.git_buf_dispose(&b);
		libgit2_d.diff.git_diff_stats_free(stats);
	}
