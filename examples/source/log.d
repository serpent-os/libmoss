/*
 * libgit2 "log" example - shows how to walk history and get commit info
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
module libgit2_d.example.log;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import core.stdc.time;
private static import libgit2_d.commit;
private static import libgit2_d.diff;
private static import libgit2_d.example.args;
private static import libgit2_d.example.common;
private static import libgit2_d.merge;
private static import libgit2_d.object;
private static import libgit2_d.oid;
private static import libgit2_d.pathspec;
private static import libgit2_d.repository;
private static import libgit2_d.revparse;
private static import libgit2_d.revwalk;
private static import libgit2_d.tree;
private static import libgit2_d.types;

package:

/**
 * This example demonstrates the libgit2 rev walker APIs to roughly
 * simulate the output of `git log` and a few of command line arguments.
 * `git log` has many many options and this only shows a few of them.
 *
 * This does not have:
 *
 * - Robust error handling
 * - Colorized or paginated output formatting
 * - Most of the `git log` options
 *
 * This does have:
 *
 * - Examples of translating command line arguments to equivalent libgit2
 *   revwalker configuration calls
 * - Simplified options to apply pathspec limits and to show basic diffs
 */

/**
 * log_state represents walker being configured while handling options
 */
public struct log_state
{
	libgit2_d.types.git_repository* repo;
	const (char)* repodir;
	libgit2_d.types.git_revwalk* walker;
	int hide;
	int sorting;
	int revisions;
}

/** utility functions that are called to configure the walker */
//private void set_sorting(.log_state* s, uint sort_mode);
//private void push_rev(.log_state* s, libgit2_d.types.git_object* obj, int hide);
//private int add_revision(.log_state* s, const (char)* revstr);

/**
 * log_options holds other command line options that affect log output
 */
public struct log_options
{
	int show_diff;
	int show_log_size;
	int skip;
	int limit;
	int min_parents;
	int max_parents;
	libgit2_d.types.git_time_t before;
	libgit2_d.types.git_time_t after;
	const (char)* author;
	const (char)* committer;
	const (char)* grep;
}

/** utility functions that parse options and help with log output */
//private int parse_options(.log_state* s, .log_options* opt, int argc, char** argv);
//private void print_time(const (libgit2_d.types.git_time)* intime, const (char)* prefix);
//private void print_commit(libgit2_d.types.git_commit* commit, .log_options* opts);
//private int match_with_parent(libgit2_d.types.git_commit* commit, int i, libgit2_d.diff.git_diff_options*);

/** utility functions for filtering */
//private int signature_matches(const (libgit2_d.types.git_signature)* sig, const (char)* filter);
//private int log_message_matches(const (libgit2_d.types.git_commit)* commit, const (char)* filter);

extern (C)
nothrow @nogc
//int lg2_log(libgit2_d.types.git_repository* repo, int argc, char*[] argv)
public int lg2_log(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		/** Parse arguments and set up revwalker. */
		.log_state s;
		.log_options opt;
		int last_arg = .parse_options(&s, &opt, argc, argv);
		s.repo = repo;

		libgit2_d.diff.git_diff_options diffopts = libgit2_d.diff.GIT_DIFF_OPTIONS_INIT();
		diffopts.pathspec.strings = &argv[last_arg];
		diffopts.pathspec.count = argc - last_arg;

		libgit2_d.pathspec.git_pathspec* ps = null;

		if (diffopts.pathspec.count > 0) {
			libgit2_d.example.common.check_lg2(libgit2_d.pathspec.git_pathspec_new(&ps, &diffopts.pathspec), "Building pathspec", null);
		}

		if (!s.revisions) {
			.add_revision(&s, null);
		}

		/** Use the revwalker to traverse the history. */

		int count = 0;
		int printed = 0;
		libgit2_d.oid.git_oid oid;
		libgit2_d.types.git_commit* commit = null;
		libgit2_d.types.git_tree* tree;
		libgit2_d.types.git_commit* parent;

		for (; !libgit2_d.revwalk.git_revwalk_next(&oid, s.walker); libgit2_d.commit.git_commit_free(commit)) {
			libgit2_d.example.common.check_lg2(libgit2_d.commit.git_commit_lookup(&commit, s.repo, &oid), "Failed to look up commit", null);

			int parents = cast(int)(libgit2_d.commit.git_commit_parentcount(commit));

			if (parents < opt.min_parents) {
				continue;
			}

			if ((opt.max_parents > 0) && (parents > opt.max_parents)) {
				continue;
			}

			if (diffopts.pathspec.count > 0) {
				int unmatched = parents;

				if (parents == 0) {
					libgit2_d.example.common.check_lg2(libgit2_d.commit.git_commit_tree(&tree, commit), "Get tree", null);

					if (libgit2_d.pathspec.git_pathspec_match_tree(null, tree, libgit2_d.pathspec.git_pathspec_flag_t.GIT_PATHSPEC_NO_MATCH_ERROR, ps) != 0) {
						unmatched = 1;
					}

					libgit2_d.tree.git_tree_free(tree);
				} else if (parents == 1) {
					unmatched = (.match_with_parent(commit, 0, &diffopts)) ? (0) : (1);
				} else {
					for (int i = 0; i < parents; ++i) {
						if (.match_with_parent(commit, i, &diffopts)) {
							unmatched--;
						}
					}
				}

				if (unmatched > 0) {
					continue;
				}
			}

			if (!.signature_matches(libgit2_d.commit.git_commit_author(commit), opt.author)) {
				continue;
			}

			if (!.signature_matches(libgit2_d.commit.git_commit_committer(commit), opt.committer)) {
				continue;
			}

			if (!.log_message_matches(commit, opt.grep)) {
				continue;
			}

			if (count++ < opt.skip) {
				continue;
			}

			if ((opt.limit != -1) && (printed++ >= opt.limit)) {
				libgit2_d.commit.git_commit_free(commit);

				break;
			}

			.print_commit(commit, &opt);

			if (opt.show_diff) {
				libgit2_d.types.git_tree* a = null;
				libgit2_d.types.git_tree* b = null;
				libgit2_d.diff.git_diff* diff = null;

				if (parents > 1) {
					continue;
				}

				libgit2_d.example.common.check_lg2(libgit2_d.commit.git_commit_tree(&b, commit), "Get tree", null);

				if (parents == 1) {
					libgit2_d.example.common.check_lg2(libgit2_d.commit.git_commit_parent(&parent, commit, 0), "Get parent", null);
					libgit2_d.example.common.check_lg2(libgit2_d.commit.git_commit_tree(&a, parent), "Tree for parent", null);
					libgit2_d.commit.git_commit_free(parent);
				}

				libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_tree_to_tree(&diff, libgit2_d.commit.git_commit_owner(commit), a, b, &diffopts), "Diff commit with parent", null);
				libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_print(diff, libgit2_d.diff.git_diff_format_t.GIT_DIFF_FORMAT_PATCH, &libgit2_d.example.common.diff_output, null), "Displaying diff", null);

				libgit2_d.diff.git_diff_free(diff);
				libgit2_d.tree.git_tree_free(a);
				libgit2_d.tree.git_tree_free(b);
			}
		}

		libgit2_d.pathspec.git_pathspec_free(ps);
		libgit2_d.revwalk.git_revwalk_free(s.walker);

		return 0;
	}

/**
 * Determine if the given libgit2_d.types.git_signature does not contain the filter text.
 */
nothrow @nogc
private int signature_matches(const (libgit2_d.types.git_signature)* sig, const (char)* filter)

	in
	{
	}

	do
	{
		if (filter == null) {
			return 1;
		}

		if ((sig != null) && ((core.stdc.string.strstr(sig.name, filter) != null) || (core.stdc.string.strstr(sig.email, filter) != null))) {
			return 1;
		}

		return 0;
	}

nothrow @nogc
private int log_message_matches(const (libgit2_d.types.git_commit)* commit, const (char)* filter)

	in
	{
	}

	do
	{
		const (char)* message = null;

		if (filter == null) {
			return 1;
		}

		message = libgit2_d.commit.git_commit_message(commit);

		if ((message != null) && (core.stdc.string.strstr(message, filter) != null)) {
			return 1;
		}

		return 0;
	}

/**
 * Push object (for hide or show) onto revwalker.
 */
nothrow @nogc
private void push_rev(.log_state* s, libgit2_d.types.git_object* obj, int hide)

	in
	{
	}

	do
	{
		hide = s.hide ^ hide;

		/** Create revwalker on demand if it doesn't already exist. */
		if (s.walker == null) {
			libgit2_d.example.common.check_lg2(libgit2_d.revwalk.git_revwalk_new(&s.walker, s.repo), "Could not create revision walker", null);
			libgit2_d.revwalk.git_revwalk_sorting(s.walker, s.sorting);
		}

		if (obj == null) {
			libgit2_d.example.common.check_lg2(libgit2_d.revwalk.git_revwalk_push_head(s.walker), "Could not find repository HEAD", null);
		} else if (hide) {
			libgit2_d.example.common.check_lg2(libgit2_d.revwalk.git_revwalk_hide(s.walker, libgit2_d.object.git_object_id(obj)), "Reference does not refer to a commit", null);
		} else {
			libgit2_d.example.common.check_lg2(libgit2_d.revwalk.git_revwalk_push(s.walker, libgit2_d.object.git_object_id(obj)), "Reference does not refer to a commit", null);
		}

		libgit2_d.object.git_object_free(obj);
	}

/**
 * Parse revision string and add revs to walker.
 */
nothrow @nogc
private int add_revision(.log_state* s, const (char)* revstr)

	in
	{
	}

	do
	{
		libgit2_d.revparse.git_revspec revs;
		int hide = 0;

		if (revstr == null) {
			.push_rev(s, null, hide);

			return 0;
		}

		if (*revstr == '^') {
			revs.flags = libgit2_d.revparse.git_revparse_mode_t.GIT_REVPARSE_SINGLE;
			hide = !hide;

			if (libgit2_d.revparse.git_revparse_single(&revs.from, s.repo, revstr + 1) < 0) {
				return -1;
			}
		} else if (libgit2_d.revparse.git_revparse(&revs, s.repo, revstr) < 0) {
			return -1;
		}

		if ((revs.flags & libgit2_d.revparse.git_revparse_mode_t.GIT_REVPARSE_SINGLE) != 0) {
			.push_rev(s, revs.from, hide);
		} else {
			.push_rev(s, revs.to, hide);

			if ((revs.flags & libgit2_d.revparse.git_revparse_mode_t.GIT_REVPARSE_MERGE_BASE) != 0) {
				libgit2_d.oid.git_oid base;
				libgit2_d.example.common.check_lg2(libgit2_d.merge.git_merge_base(&base, s.repo, libgit2_d.object.git_object_id(revs.from), libgit2_d.object.git_object_id(revs.to)), "Could not find merge base", revstr);
				libgit2_d.example.common.check_lg2(libgit2_d.object.git_object_lookup(&revs.to, s.repo, &base, libgit2_d.types.git_object_t.GIT_OBJECT_COMMIT), "Could not find merge base commit", null);

				.push_rev(s, revs.to, hide);
			}

			.push_rev(s, revs.from, !hide);
		}

		return 0;
	}

/**
 * Update revwalker with sorting mode.
 */
nothrow @nogc
private void set_sorting(.log_state* s, uint sort_mode)

	in
	{
	}

	do
	{
		/** Open repo on demand if it isn't already open. */
		if (s.repo == null) {
			if (s.repodir == null) {
				s.repodir = ".";
			}

			libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_open_ext(&s.repo, s.repodir, 0, null), "Could not open repository", s.repodir);
		}

		/** Create revwalker on demand if it doesn't already exist. */
		if (s.walker == null) {
			libgit2_d.example.common.check_lg2(libgit2_d.revwalk.git_revwalk_new(&s.walker, s.repo), "Could not create revision walker", null);
		}

		if (sort_mode == libgit2_d.revwalk.git_sort_t.GIT_SORT_REVERSE) {
			s.sorting = s.sorting ^ libgit2_d.revwalk.git_sort_t.GIT_SORT_REVERSE;
		} else {
			s.sorting = sort_mode | (s.sorting & libgit2_d.revwalk.git_sort_t.GIT_SORT_REVERSE);
		}

		libgit2_d.revwalk.git_revwalk_sorting(s.walker, s.sorting);
	}

/**
 * Helper to format a libgit2_d.types.git_time value like Git.
 */
nothrow @nogc
private void print_time(const (libgit2_d.types.git_time)* intime, const (char)* prefix)

	in
	{
	}

	do
	{
		char sign;
		int offset = intime.offset;

		if (offset < 0) {
			sign = '-';
			offset = -offset;
		} else {
			sign = '+';
		}

		int hours = offset / 60;
		int minutes = offset % 60;

		core.stdc.time.time_t t = cast(core.stdc.time.time_t)(intime.time) + (intime.offset * 60);

		core.stdc.time.tm* intm = core.stdc.time.gmtime(&t);
		char[32] out_;
		core.stdc.time.strftime(&(out_[0]), out_.length, "%a %b %e %T %Y", intm);

		core.stdc.stdio.printf("%s%s %c%02d%02d\n", prefix, &(out_[0]), sign, hours, minutes);
	}

/**
 * Helper to print a commit object.
 */
nothrow @nogc
private void print_commit(libgit2_d.types.git_commit* commit, .log_options* opts)

	in
	{
	}

	do
	{
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] buf;
		libgit2_d.oid.git_oid_tostr(&(buf[0]), buf.length, libgit2_d.commit.git_commit_id(commit));
		core.stdc.stdio.printf("commit %s\n", &(buf[0]));

		if (opts.show_log_size) {
			core.stdc.stdio.printf("log size %d\n", cast(int)(core.stdc.string.strlen(libgit2_d.commit.git_commit_message(commit))));
		}

		int count = cast(int)(libgit2_d.commit.git_commit_parentcount(commit));

		if (count > 1) {
			core.stdc.stdio.printf("Merge:");

			for (int i = 0; i < count; ++i) {
				libgit2_d.oid.git_oid_tostr(&(buf[0]), 8, libgit2_d.commit.git_commit_parent_id(commit, i));
				core.stdc.stdio.printf(" %s", &(buf[0]));
			}

			core.stdc.stdio.printf("\n");
		}

		const (libgit2_d.types.git_signature)* sig = libgit2_d.commit.git_commit_author(commit);

		if (sig != null) {
			core.stdc.stdio.printf("Author: %s <%s>\n", sig.name, sig.email);
			.print_time(&sig.when, "Date:   ");
		}

		core.stdc.stdio.printf("\n");
		const (char)* scan;
		const (char)* eol;

		for (scan = libgit2_d.commit.git_commit_message(commit); (scan) && (*scan); ) {
			for (eol = scan; (*eol) && (*eol != '\n'); ++eol) {/* find eol */
			}

			core.stdc.stdio.printf("    %.*s\n", cast(int)(eol - scan), scan);
			scan = (*eol) ? (eol + 1) : (null);
		}

		core.stdc.stdio.printf("\n");
	}

/**
 * Helper to find how many files in a commit changed from its nth parent.
 */
nothrow @nogc
private int match_with_parent(libgit2_d.types.git_commit* commit, int i, libgit2_d.diff.git_diff_options* opts)

	in
	{
	}

	do
	{
		libgit2_d.types.git_commit* parent;
		libgit2_d.types.git_tree* a;
		libgit2_d.types.git_tree* b;
		libgit2_d.diff.git_diff* diff;

		libgit2_d.example.common.check_lg2(libgit2_d.commit.git_commit_parent(&parent, commit, cast(size_t)(i)), "Get parent", null);
		libgit2_d.example.common.check_lg2(libgit2_d.commit.git_commit_tree(&a, parent), "Tree for parent", null);
		libgit2_d.example.common.check_lg2(libgit2_d.commit.git_commit_tree(&b, commit), "Tree for commit", null);
		libgit2_d.example.common.check_lg2(libgit2_d.diff.git_diff_tree_to_tree(&diff, libgit2_d.commit.git_commit_owner(commit), a, b, opts), "Checking diff between parent and commit", null);

		int ndeltas = cast(int)(libgit2_d.diff.git_diff_num_deltas(diff));

		libgit2_d.diff.git_diff_free(diff);
		libgit2_d.tree.git_tree_free(a);
		libgit2_d.tree.git_tree_free(b);
		libgit2_d.commit.git_commit_free(parent);

		return ndeltas > 0;
	}

/**
 * Print a usage message for the program.
 */
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

		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: log [<options>]\n");
		core.stdc.stdlib.exit(1);
	}

/**
 * Parse some log command line options.
 */
nothrow @nogc
private int parse_options(.log_state* s, .log_options* opt, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);

		core.stdc.string.memset(s, 0, (*s).sizeof);
		s.sorting = libgit2_d.revwalk.git_sort_t.GIT_SORT_TIME;

		core.stdc.string.memset(opt, 0, (*opt).sizeof);
		opt.max_parents = -1;
		opt.limit = -1;

		for (args.pos = 1; args.pos < argc; ++args.pos) {
			const (char)* a = argv[args.pos];

			if (a[0] != '-') {
				if (!.add_revision(s, a)) {
					s.revisions++;
				} else {
					/** Try failed revision parse as filename. */
					break;
				}
			} else if (!libgit2_d.example.args.match_arg_separator(&args)) {
				break;
			} else if (!core.stdc.string.strcmp(a, "--date-order")) {
				.set_sorting(s, libgit2_d.revwalk.git_sort_t.GIT_SORT_TIME);
			} else if (!core.stdc.string.strcmp(a, "--topo-order")) {
				.set_sorting(s, libgit2_d.revwalk.git_sort_t.GIT_SORT_TOPOLOGICAL);
			} else if (!core.stdc.string.strcmp(a, "--reverse")) {
				.set_sorting(s, libgit2_d.revwalk.git_sort_t.GIT_SORT_REVERSE);
			} else if (libgit2_d.example.args.match_str_arg(&opt.author, &args, "--author")) {
				/** Found valid --author */
			} else if (libgit2_d.example.args.match_str_arg(&opt.committer, &args, "--committer")) {
				/** Found valid --committer */
			} else if (libgit2_d.example.args.match_str_arg(&opt.grep, &args, "--grep")) {
				/** Found valid --grep */
			} else if (libgit2_d.example.args.match_str_arg(&s.repodir, &args, "--git-dir")) {
				/** Found git-dir. */
			} else if (libgit2_d.example.args.match_int_arg(&opt.skip, &args, "--skip", 0)) {
				/** Found valid --skip. */
			} else if (libgit2_d.example.args.match_int_arg(&opt.limit, &args, "--max-count", 0)) {
				/** Found valid --max-count. */
			} else if ((a[1] >= '0') && (a[1] <= '9')) {
				libgit2_d.example.args.is_integer(&opt.limit, a + 1, 0);
			} else if (libgit2_d.example.args.match_int_arg(&opt.limit, &args, "-n", 0)) {
				/** Found valid -n. */
			} else if (!core.stdc.string.strcmp(a, "--merges")) {
				opt.min_parents = 2;
			} else if (!core.stdc.string.strcmp(a, "--no-merges")) {
				opt.max_parents = 1;
			} else if (!core.stdc.string.strcmp(a, "--no-min-parents")) {
				opt.min_parents = 0;
			} else if (!core.stdc.string.strcmp(a, "--no-max-parents")) {
				opt.max_parents = -1;
			} else if (libgit2_d.example.args.match_int_arg(&opt.max_parents, &args, "--max-parents=", 1)) {
				/** Found valid --max-parents. */
			} else if (libgit2_d.example.args.match_int_arg(&opt.min_parents, &args, "--min-parents=", 0)) {
				/** Found valid --min_parents. */
			} else if ((!core.stdc.string.strcmp(a, "-p")) || (!core.stdc.string.strcmp(a, "-u")) || (!core.stdc.string.strcmp(a, "--patch"))) {
				opt.show_diff = 1;
			} else if (!core.stdc.string.strcmp(a, "--log-size")) {
				opt.show_log_size = 1;
			} else {
				.usage("Unsupported argument", a);
			}
		}

		return args.pos;
	}
