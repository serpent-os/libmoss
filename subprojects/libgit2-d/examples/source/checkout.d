/*	
 * libgit2 "checkout" example - shows how to perform checkouts
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
module libgit2_d.example.checkout;


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
private static import libgit2_d.refs;
private static import libgit2_d.remote;
private static import libgit2_d.repository;
private static import libgit2_d.strarray;
private static import libgit2_d.types;
private static import std.bitmanip;

package:

/* Define the printf format specifer to use for size_t output */
//#if defined(_MSC_VER) || defined(__MINGW32__)
version (Windows) {
	enum PRIuZ = "Iu";
	enum PRIxZ = "Ix";
	enum PRIdZ = "Id";
} else {
	enum PRIuZ = "zu";
	enum PRIxZ = "zx";
	enum PRIdZ = "zd";
}

/**
 * The following example demonstrates how to do checkouts with libgit2.
 *
 * Recognized options are :
 *  --force: force the checkout to happen.
 *  --[no-]progress: show checkout progress, on by default.
 *  --perf: show performance data.
 */

public struct checkout_options
{
	mixin
	(
		std.bitmanip.bitfields!
		(
			int, "force", 1,
			int, "progress", 1,
			int, "perf", 1,
			int, "not_used", 5
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
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr,
			"usage: checkout [options] <branch>\n"
			~ "Options are :\n"
			~ "  --git-dir: use the following git repository.\n"
			~ "  --force: force the checkout.\n"
			~ "  --[no-]progress: show checkout progress.\n"
			~ "  --perf: show performance data.\n");

		core.stdc.stdlib.exit(1);
	}

nothrow @nogc
private void parse_options(const (char)** repo_path, .checkout_options* opts, libgit2_d.example.args.args_info* args)

	in
	{
	}

	do
	{
		if (args.argc <= 1) {
			.print_usage();
		}

		core.stdc.string.memset(opts, 0, (*opts).sizeof);

		/* Default values */
		opts.progress = 1;

		int bool_arg;

		for (args.pos = 1; args.pos < args.argc; ++args.pos) {
			const (char)* curr = args.argv[args.pos];

			if (libgit2_d.example.args.match_arg_separator(args)) {
				break;
			} else if (!core.stdc.string.strcmp(curr, "--force")) {
				opts.force = 1;
			} else if (libgit2_d.example.args.match_bool_arg(&bool_arg, args, "--progress")) {
				opts.progress = bool_arg;
			} else if (libgit2_d.example.args.match_bool_arg(&bool_arg, args, "--perf")) {
				opts.perf = bool_arg;
			} else if (libgit2_d.example.args.match_str_arg(repo_path, args, "--git-dir")) {
				continue;
			} else {
				break;
			}
		}
	}

/**
 * This function is called to report progression, ie. it's called once with
 * a null path and the number of total steps, then for each subsequent path,
 * the current completed_step value.
 */
extern (C)
nothrow @nogc
private void print_checkout_progress(const (char)* path, size_t completed_steps, size_t total_steps, void* payload)

	in
	{
	}

	do
	{
		//cast(void)(payload);

		if (path == null) {
			core.stdc.stdio.printf("checkout started: %" ~ .PRIuZ ~ " steps\n", total_steps);
		} else {
			core.stdc.stdio.printf("checkout: %s %" ~ .PRIuZ ~ "/%" ~ .PRIuZ ~ "\n", path, completed_steps, total_steps);
		}
	}

/**
 * This function is called when the checkout completes, and is used to report the
 * number of syscalls performed.
 */
extern (C)
nothrow @nogc
private void print_perf_data(const (libgit2_d.checkout.git_checkout_perfdata)* perfdata, void* payload)

	in
	{
	}

	do
	{
		//cast(void)(payload);
		core.stdc.stdio.printf("perf: stat: %" ~ .PRIuZ ~ " mkdir: %" ~ .PRIuZ ~ " chmod: %" ~ .PRIuZ ~ "\n", perfdata.stat_calls, perfdata.mkdir_calls, perfdata.chmod_calls);
	}

/**
 * This is the main "checkout <branch>" function, responsible for performing
 * a branch-based checkout.
 */
nothrow @nogc
private int perform_checkout_ref(libgit2_d.types.git_repository* repo, const (char)* target_ref, libgit2_d.types.git_annotated_commit* target, .checkout_options* opts)

	in
	{
	}

	do
	{
		/** Setup our checkout options from the parsed options */
		libgit2_d.checkout.git_checkout_options checkout_opts = libgit2_d.checkout.GIT_CHECKOUT_OPTIONS_INIT();
		checkout_opts.checkout_strategy = libgit2_d.checkout.git_checkout_strategy_t.GIT_CHECKOUT_SAFE;

		if (opts.force) {
			checkout_opts.checkout_strategy = libgit2_d.checkout.git_checkout_strategy_t.GIT_CHECKOUT_FORCE;
		}

		if (opts.progress) {
			checkout_opts.progress_cb = &.print_checkout_progress;
		}

		if (opts.perf) {
			checkout_opts.perfdata_cb = &.print_perf_data;
		}

		/** Grab the commit we're interested to move to */
		libgit2_d.types.git_reference* ref_ = null;
		libgit2_d.types.git_commit* target_commit = null;

		scope (exit) {
			libgit2_d.commit.git_commit_free(target_commit);
			libgit2_d.commit.git_commit_free(cast(libgit2_d.types.git_commit*)(ref_));
		}

		int err = libgit2_d.commit.git_commit_lookup(&target_commit, repo, libgit2_d.annotated_commit.git_annotated_commit_id(target));

		if (err != 0) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to lookup commit: %s\n", libgit2_d.errors.git_error_last().message);

			return err;
		}

		/**
		 * Perform the checkout so the workdir corresponds to what target_commit
		 * contains.
		 *
		 * Note that it's okay to pass a git_commit here, because it will be
		 * peeled to a tree.
		 */
		err = libgit2_d.checkout.git_checkout_tree(repo, cast(const (libgit2_d.types.git_object)*)(target_commit), &checkout_opts);

		if (err != 0) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to checkout tree: %s\n", libgit2_d.errors.git_error_last().message);

			return err;
		}

		/**
		 * Now that the checkout has completed, we have to update HEAD.
		 *
		 * Depending on the "origin" of target (ie. it's an OID or a branch name),
		 * we might need to detach HEAD.
		 */
		libgit2_d.types.git_reference* branch = null;

		scope (exit) {
			libgit2_d.refs.git_reference_free(branch);
		}

		if (libgit2_d.annotated_commit.git_annotated_commit_ref(target)) {
			err = libgit2_d.refs.git_reference_lookup(&ref_, repo, libgit2_d.annotated_commit.git_annotated_commit_ref(target));

			if (err < 0) {
				goto error;
			}

			const (char)* target_head;

			if (libgit2_d.refs.git_reference_is_remote(ref_)) {
				err = libgit2_d.branch.git_branch_create_from_annotated(&branch, repo, target_ref, target, 0);

				if (err < 0) {
					goto error;
				}

				target_head = libgit2_d.refs.git_reference_name(branch);
			} else {
				target_head = libgit2_d.annotated_commit.git_annotated_commit_ref(target);
			}

			err = libgit2_d.repository.git_repository_set_head(repo, target_head);
		} else {
			err = libgit2_d.repository.git_repository_set_head_detached_from_annotated(repo, target);
		}

error:
		if (err != 0) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to update HEAD reference: %s\n", libgit2_d.errors.git_error_last().message);

			return err;
		}

		return err;
	}

/**
 * This corresponds to `git switch --guess`: if a given ref does
 * not exist, git will by default try to guess the reference by
 * seeing whether any remote has a branch called <ref>. If there
 * is a single remote only that has it, then it is assumed to be
 * the desired reference and a local branch is created for it.
 *
 * The following is a simplified implementation. It will not try
 * to check whether the ref is unique across all remotes.
 */
nothrow @nogc
private int guess_refish(libgit2_d.types.git_annotated_commit** out_, libgit2_d.types.git_repository* repo, const (char)* ref_)

	do
	{
		libgit2_d.strarray.git_strarray remotes =
		{
			null,
			0,
		};
		libgit2_d.types.git_reference* remote_ref = null;

		scope (exit) {
			libgit2_d.refs.git_reference_free(remote_ref);
			libgit2_d.strarray.git_strarray_dispose(&remotes);
		}

		int error = libgit2_d.remote.git_remote_list(&remotes, repo);

		if (error < 0) {
			return error;
		}

		for (size_t i = 0; i < remotes.count; i++) {
			char* refname = null;
			size_t reflen = libgit2_d.example.common.snprintf(refname, 0, "refs/remotes/%s/%s", remotes.strings[i], ref_);
			refname = cast(char*)(core.stdc.stdlib.malloc(reflen + 1));

			if (refname == null) {
				error = -1;

				goto next;
			}

			libgit2_d.example.common.snprintf(refname, reflen + 1, "refs/remotes/%s/%s", remotes.strings[i], ref_);
			error = libgit2_d.refs.git_reference_lookup(&remote_ref, repo, refname);

			if (error < 0) {
				goto next;
			}

			break;

	next:
			if (refname != null) {
				core.stdc.stdlib.free(refname);
			}

			if ((error < 0) && (error != libgit2_d.errors.git_error_code.GIT_ENOTFOUND)) {
				break;
			}
		}

		if (!remote_ref) {
			error = libgit2_d.errors.git_error_code.GIT_ENOTFOUND;
			return error;
		}

		if ((error = libgit2_d.annotated_commit.git_annotated_commit_from_ref(out_, repo, remote_ref)) < 0) {
			return error;
		}

		return error;
	}

/**
 * That example's entry point
 */
extern (C)
nothrow @nogc
public int lg2_checkout(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.types.git_annotated_commit* checkout_target = null;
		int err = 0;
		const (char)* path = ".";

		scope (exit) {
			libgit2_d.annotated_commit.git_annotated_commit_free(checkout_target);
		}

		/** Parse our command line options */
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);
		.checkout_options opts;
		.parse_options(&path, &opts, &args);

		/** Make sure we're not about to checkout while something else is going on */
		//libgit2_d.repository.git_repository_state_t state
		int state = libgit2_d.repository.git_repository_state(repo);

		if (state != libgit2_d.repository.git_repository_state_t.GIT_REPOSITORY_STATE_NONE) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "repository is in unexpected state %d\n", state);

			return err;
		}

		if (libgit2_d.example.args.match_arg_separator(&args)) {
			/**
			 * Try to checkout the given path
			 */

			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "unhandled path-based checkout\n");
			err = 1;

			return err;
		} else {
			/**
			 * Try to resolve a "refish" argument to a target libgit2 can use
			 */
			if (((err = libgit2_d.example.common.resolve_refish(&checkout_target, repo, args.argv[args.pos])) < 0) && ((err = .guess_refish(&checkout_target, repo, args.argv[args.pos])) < 0)) {
				core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "failed to resolve %s: %s\n", args.argv[args.pos], libgit2_d.errors.git_error_last().message);

				return err;
			}

			err = .perform_checkout_ref(repo, cast(const (char)*)(checkout_target), cast(libgit2_d.types.git_annotated_commit*)(args.argv[args.pos]), &opts);
		}

		return err;
	}
