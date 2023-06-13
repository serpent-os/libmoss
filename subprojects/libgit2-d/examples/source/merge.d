/*
 * libgit2 "merge" example - shows how to perform merges
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
module libgit2_d.example.merge;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.annotated_commit;
private static import libgit2_d.branch;
private static import libgit2_d.checkout;
private static import libgit2_d.commit;
private static import libgit2_d.errors;
private static import libgit2_d.example.args;
private static import libgit2_d.example.common;
private static import libgit2_d.index;
private static import libgit2_d.merge;
private static import libgit2_d.object;
private static import libgit2_d.oid;
private static import libgit2_d.refs;
private static import libgit2_d.repository;
private static import libgit2_d.signature;
private static import libgit2_d.tree;
private static import libgit2_d.types;
private static import std.bitmanip;

package:

/** The following example demonstrates how to do merges with libgit2.
 *
 * It will merge whatever commit-ish you pass in into the current branch.
 *
 * Recognized options are :
 *  --no-commit: don't actually commit the merge.
 *
 */

public struct merge_options
{
	const (char)** heads;
	size_t heads_count;

	libgit2_d.types.git_annotated_commit** annotated;
	size_t annotated_count;

	mixin
	(
		std.bitmanip.bitfields!
		(
			int, "no_commit", 1,
			int, "not_used", 7
		)
	);
}

nothrow @nogc
private void print_usage()

	in
	{
	}

	do
	{
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: merge [--no-commit] <commit...>\n");
		core.stdc.stdlib.exit(1);
	}

nothrow @nogc
private void merge_options_init(.merge_options* opts)

	in
	{
	}

	do
	{
		core.stdc.string.memset(opts, 0, (*opts).sizeof);

		opts.heads = null;
		opts.heads_count = 0;
		opts.annotated = null;
		opts.annotated_count = 0;
	}

nothrow @nogc
private void opts_add_refish(.merge_options* opts, const (char)* refish)

	in
	{
		assert(opts != null);
	}

	do
	{
		size_t sz = ++opts.heads_count * opts.heads[0].sizeof;
		opts.heads = cast(const (char)**)(libgit2_d.example.common.xrealloc(cast(void*)(opts.heads), sz));
		opts.heads[opts.heads_count - 1] = refish;
	}

nothrow @nogc
private void parse_options(const (char)** repo_path, .merge_options* opts, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);

		if (argc <= 1) {
			.print_usage();
		}

		for (args.pos = 1; args.pos < argc; ++args.pos) {
			const (char)* curr = argv[args.pos];

			if (curr[0] != '-') {
				.opts_add_refish(opts, curr);
			} else if (!core.stdc.string.strcmp(curr, "--no-commit")) {
				opts.no_commit = 1;
			} else if (libgit2_d.example.args.match_str_arg(repo_path, &args, "--git-dir")) {
				continue;
			} else {
				.print_usage();
			}
		}
	}

nothrow @nogc
private int resolve_heads(libgit2_d.types.git_repository* repo, .merge_options* opts)

	in
	{
	}

	do
	{
		libgit2_d.types.git_annotated_commit** annotated = cast(libgit2_d.types.git_annotated_commit**)(core.stdc.stdlib.calloc(opts.heads_count, (libgit2_d.types.git_annotated_commit*).sizeof));
		size_t annotated_count = 0;

		for (size_t i = 0; i < opts.heads_count; i++) {
			int err = libgit2_d.example.common.resolve_refish(&annotated[annotated_count++], repo, opts.heads[i]);

			if (err != 0) {
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to resolve refish %s: %s\n", opts.heads[i], libgit2_d.errors.git_error_last().message);
				annotated_count--;

				continue;
			}
		}

		if (annotated_count != opts.heads_count) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "unable to parse some refish\n");
			core.stdc.stdlib.free(annotated);

			return -1;
		}

		opts.annotated = annotated;
		opts.annotated_count = annotated_count;

		return 0;
	}

nothrow @nogc
private int perform_fastforward(libgit2_d.types.git_repository* repo, const (libgit2_d.oid.git_oid)* target_oid, int is_unborn)

	in
	{
	}

	do
	{
		libgit2_d.checkout.git_checkout_options ff_checkout_options = libgit2_d.checkout.GIT_CHECKOUT_OPTIONS_INIT();
		libgit2_d.types.git_reference* target_ref;
		int err = 0;

		if (is_unborn) {
			libgit2_d.types.git_reference* head_ref;

			/* HEAD reference is unborn, lookup manually so we don't try to resolve it */
			err = libgit2_d.refs.git_reference_lookup(&head_ref, repo, "HEAD");

			if (err != 0) {
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to lookup HEAD ref\n");

				return -1;
			}

			/* Grab the reference HEAD should be pointing to */
			const (char)* symbolic_ref = libgit2_d.refs.git_reference_symbolic_target(head_ref);

			/* Create our master reference on the target OID */
			err = libgit2_d.refs.git_reference_create(&target_ref, repo, symbolic_ref, target_oid, 0, null);

			if (err != 0) {
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to create master reference\n");

				return -1;
			}

			libgit2_d.refs.git_reference_free(head_ref);
		} else {
			/* HEAD exists, just lookup and resolve */
			err = libgit2_d.repository.git_repository_head(&target_ref, repo);

			if (err != 0) {
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to get HEAD reference\n");

				return -1;
			}
		}

		/* Lookup the target object */
		libgit2_d.types.git_object* target = null;
		err = libgit2_d.object.git_object_lookup(&target, repo, target_oid, libgit2_d.types.git_object_t.GIT_OBJECT_COMMIT);

		if (err != 0) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to lookup OID %s\n", libgit2_d.oid.git_oid_tostr_s(target_oid));

			return -1;
		}

		/* Checkout the result so the workdir is in the expected state */
		ff_checkout_options.checkout_strategy = libgit2_d.checkout.git_checkout_strategy_t.GIT_CHECKOUT_SAFE;
		err = libgit2_d.checkout.git_checkout_tree(repo, target, &ff_checkout_options);

		if (err != 0) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to checkout HEAD reference\n");

			return -1;
		}

		/* Move the target reference to the target OID */
		libgit2_d.types.git_reference* new_target_ref;
		err = libgit2_d.refs.git_reference_set_target(&new_target_ref, target_ref, target_oid, null);

		if (err != 0) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to move HEAD reference\n");

			return -1;
		}

		libgit2_d.refs.git_reference_free(target_ref);
		libgit2_d.refs.git_reference_free(new_target_ref);
		libgit2_d.object.git_object_free(target);

		return 0;
	}

nothrow @nogc
private void output_conflicts(libgit2_d.types.git_index* index)

	in
	{
	}

	do
	{
		libgit2_d.types.git_index_conflict_iterator* conflicts;
		libgit2_d.example.common.check_lg2(libgit2_d.index.git_index_conflict_iterator_new(&conflicts, index), "failed to create conflict iterator", null);

		const (libgit2_d.index.git_index_entry)* ancestor;
		const (libgit2_d.index.git_index_entry)* our;
		const (libgit2_d.index.git_index_entry)* their;
		int err = 0;

		while ((err = libgit2_d.index.git_index_conflict_next(&ancestor, &our, &their, conflicts)) == 0) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "conflict: a:%s o:%s t:%s\n", (ancestor) ? (ancestor.path) : ("null"), (our.path) ? (our.path) : ("null"), (their.path) ? (their.path) : ("null"));
		}

		if (err != libgit2_d.errors.git_error_code.GIT_ITEROVER) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "error iterating conflicts\n");
		}

		libgit2_d.index.git_index_conflict_iterator_free(conflicts);
	}

nothrow @nogc
private int create_merge_commit(libgit2_d.types.git_repository* repo, libgit2_d.types.git_index* index, .merge_options* opts)

	in
	{
	}

	do
	{
		libgit2_d.types.git_commit** parents = cast(libgit2_d.types.git_commit**)(core.stdc.stdlib.calloc(opts.annotated_count + 1, (libgit2_d.types.git_commit*).sizeof));

		scope (exit) {
			if (parents != null) {
				core.stdc.stdlib.free(parents);
				parents = null;
			}
		}

		/* Grab our needed references */
		libgit2_d.types.git_reference* head_ref;
		libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_head(&head_ref, repo), "failed to get repo HEAD", null);

		libgit2_d.types.git_annotated_commit* merge_commit;

		if (libgit2_d.example.common.resolve_refish(&merge_commit, repo, opts.heads[0])) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to resolve refish %s", opts.heads[0]);

			return -1;
		}

		/* Maybe that's a ref, so DWIM it */
		libgit2_d.types.git_reference* merge_ref = null;
		int err = libgit2_d.refs.git_reference_dwim(&merge_ref, repo, opts.heads[0]);
		libgit2_d.example.common.check_lg2(err, "failed to DWIM reference", libgit2_d.errors.git_error_last().message);

		/* Grab a signature */
		libgit2_d.types.git_signature* sign;
		libgit2_d.example.common.check_lg2(libgit2_d.signature.git_signature_now(&sign, "Me", "me@example.com"), "failed to create signature", null);

		enum MERGE_COMMIT_MSG = "Merge %s '%s'";

		const (char)* msg_target = null;

		/* Prepare a standard merge commit message */
		if (merge_ref != null) {
			libgit2_d.example.common.check_lg2(libgit2_d.branch.git_branch_name(&msg_target, merge_ref), "failed to get branch name of merged ref", null);
		} else {
			msg_target = libgit2_d.oid.git_oid_tostr_s(libgit2_d.annotated_commit.git_annotated_commit_id(merge_commit));
		}

		size_t msglen = libgit2_d.example.common.snprintf(null, 0, MERGE_COMMIT_MSG, ((merge_ref) ? (&("branch\0"[0])) : (&("commit\0"[0]))), msg_target);

		if (msglen > 0) {
			msglen++;
		}

		char* msg = cast(char*)(core.stdc.stdlib.malloc(msglen));
		err = libgit2_d.example.common.snprintf(msg, msglen, MERGE_COMMIT_MSG, ((merge_ref) ? (&("branch\0"[0])) : (&("commit\0"[0]))), msg_target);

		/* This is only to silence the compiler */
		if (err < 0) {
			return err;
		}

		/* Setup our parent commits */
		err = libgit2_d.refs.git_reference_peel(cast(libgit2_d.types.git_object**)(&parents[0]), head_ref, libgit2_d.types.git_object_t.GIT_OBJECT_COMMIT);
		libgit2_d.example.common.check_lg2(err, "failed to peel head reference", null);

		for (size_t i = 0; i < opts.annotated_count; i++) {
			libgit2_d.commit.git_commit_lookup(&parents[i + 1], repo, libgit2_d.annotated_commit.git_annotated_commit_id(opts.annotated[i]));
		}

		/* Prepare our commit tree */
		libgit2_d.oid.git_oid tree_oid;
		libgit2_d.example.common.check_lg2(libgit2_d.index.git_index_write_tree(&tree_oid, index), "failed to write merged tree", null);
		libgit2_d.types.git_tree* tree;
		libgit2_d.example.common.check_lg2(libgit2_d.tree.git_tree_lookup(&tree, repo, &tree_oid), "failed to lookup tree", null);

		/* Commit time ! */
		libgit2_d.oid.git_oid commit_oid;
		err = libgit2_d.commit.git_commit_create(&commit_oid, repo, libgit2_d.refs.git_reference_name(head_ref), sign, sign, null, msg, tree, opts.annotated_count + 1, cast(const (libgit2_d.types.git_commit)**)(parents));
		libgit2_d.example.common.check_lg2(err, "failed to create commit", null);

		/* We're done merging, cleanup the repository state */
		libgit2_d.repository.git_repository_state_cleanup(repo);

		return err;
	}

extern (C)
nothrow @nogc
public int lg2_merge(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		.merge_options opts;
		.merge_options_init(&opts);
		const (char)* path = ".";
		.parse_options(&path, &opts, argc, argv);

		scope (exit) {
			if (opts.heads != null) {
				core.stdc.stdlib.free(cast(char**)(opts.heads));
				opts.heads = null;
			}

			if (opts.annotated != null) {
				core.stdc.stdlib.free(opts.annotated);
				opts.annotated = null;
			}
		}

		//libgit2_d.repository.git_repository_state_t state
		int state = libgit2_d.repository.git_repository_state(repo);

		if (state != libgit2_d.repository.git_repository_state_t.GIT_REPOSITORY_STATE_NONE) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "repository is in unexpected state %d\n", state);

			return 0;
		}

		int err = .resolve_heads(repo, &opts);

		if (err != 0) {
			return 0;
		}

		libgit2_d.merge.git_merge_analysis_t analysis;
		libgit2_d.merge.git_merge_preference_t preference;
		err = libgit2_d.merge.git_merge_analysis(&analysis, &preference, repo, cast(const (libgit2_d.types.git_annotated_commit)**)(opts.annotated), opts.annotated_count);
		libgit2_d.example.common.check_lg2(err, "merge analysis failed", null);

		if (analysis & libgit2_d.merge.git_merge_analysis_t.GIT_MERGE_ANALYSIS_UP_TO_DATE) {
			core.stdc.stdio.printf("Already up-to-date\n");

			return 0;
		} else if ((analysis & libgit2_d.merge.git_merge_analysis_t.GIT_MERGE_ANALYSIS_UNBORN) || ((analysis & libgit2_d.merge.git_merge_analysis_t.GIT_MERGE_ANALYSIS_FASTFORWARD) && (!(preference & libgit2_d.merge.git_merge_preference_t.GIT_MERGE_PREFERENCE_NO_FASTFORWARD)))) {
			const (libgit2_d.oid.git_oid)* target_oid;

			if (analysis & libgit2_d.merge.git_merge_analysis_t.GIT_MERGE_ANALYSIS_UNBORN) {
				core.stdc.stdio.printf("Unborn\n");
			} else {
				core.stdc.stdio.printf("Fast-forward\n");
			}

			/* Since this is a fast-forward, there can be only one merge head */
			target_oid = libgit2_d.annotated_commit.git_annotated_commit_id(opts.annotated[0]);
			assert(opts.annotated_count == 1);

			return .perform_fastforward(repo, target_oid, (analysis & libgit2_d.merge.git_merge_analysis_t.GIT_MERGE_ANALYSIS_UNBORN));
		} else if (analysis & libgit2_d.merge.git_merge_analysis_t.GIT_MERGE_ANALYSIS_NORMAL) {
			libgit2_d.merge.git_merge_options merge_opts = libgit2_d.merge.GIT_MERGE_OPTIONS_INIT();
			libgit2_d.checkout.git_checkout_options checkout_opts = libgit2_d.checkout.GIT_CHECKOUT_OPTIONS_INIT();

			merge_opts.flags = 0;
			merge_opts.file_flags = libgit2_d.merge.git_merge_file_flag_t.GIT_MERGE_FILE_STYLE_DIFF3;

			checkout_opts.checkout_strategy = libgit2_d.checkout.git_checkout_strategy_t.GIT_CHECKOUT_FORCE | libgit2_d.checkout.git_checkout_strategy_t.GIT_CHECKOUT_ALLOW_CONFLICTS;

			if (preference & libgit2_d.merge.git_merge_preference_t.GIT_MERGE_PREFERENCE_FASTFORWARD_ONLY) {
				core.stdc.stdio.printf("Fast-forward is preferred, but only a merge is possible\n");

				return -1;
			}

			err = libgit2_d.merge.git_merge(repo, cast(const (libgit2_d.types.git_annotated_commit)**)(opts.annotated), opts.annotated_count, &merge_opts, &checkout_opts);
			libgit2_d.example.common.check_lg2(err, "merge failed", null);
		}

		/* If we get here, we actually performed the merge above */

		libgit2_d.types.git_index* index;
		libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_index(&index, repo), "failed to get repository index", null);

		if (libgit2_d.index.git_index_has_conflicts(index)) {
			/* Handle conflicts */
			.output_conflicts(index);
		} else if (!opts.no_commit) {
			.create_merge_commit(repo, index, &opts);
			core.stdc.stdio.printf("Merge made\n");
		}

		return 0;
	}
