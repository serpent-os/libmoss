/*
 * libgit2 "init" example - shows how to initialize a new repo
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
module libgit2_d.example.init;


private static import core.stdc.config;
private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.commit;
private static import libgit2_d.example.args;
private static import libgit2_d.example.common;
private static import libgit2_d.index;
private static import libgit2_d.oid;
private static import libgit2_d.repository;
private static import libgit2_d.signature;
private static import libgit2_d.tree;
private static import libgit2_d.types;

package:

/**
 * This is a sample program that is similar to "git init".  See the
 * documentation for that (try "git help init") to understand what this
 * program is emulating.
 *
 * This demonstrates using the libgit2 APIs to initialize a new repository.
 *
 * This also contains a special additional option that regular "git init"
 * does not support which is "--initial-commit" to make a first empty commit.
 * That is demonstrated in the "create_initial_commit" helper function.
 */

/**
 * Forward declarations of helpers
 */
public struct init_opts
{
	int no_options;
	int quiet;
	int bare;
	int initial_commit;
	uint shared_;
	const (char)* template_;
	const (char)* gitdir;
	const (char)* dir;
}

extern (C)
nothrow @nogc
//int lg2_init(libgit2_d.types.git_repository* repo, int argc, char*[] argv)
public int lg2_init(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		.init_opts o = {1, 0, 0, 0, libgit2_d.repository.git_repository_init_mode_t.GIT_REPOSITORY_INIT_SHARED_UMASK, null, null, null};

		.parse_opts(&o, argc, argv);

		/* Initialize repository. */

		if (o.no_options) {
			/**
			 * No options were specified, so let's demonstrate the default
			 * simple case of libgit2_d.repository.git_repository_init() API usage...
			 */
			libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_init(&repo, o.dir, 0), "Could not initialize repository", null);
		} else {
			/**
			 * Some command line options were specified, so we'll use the
			 * extended init API to handle them
			 */
			libgit2_d.repository.git_repository_init_options initopts = libgit2_d.repository.GIT_REPOSITORY_INIT_OPTIONS_INIT();
			initopts.flags = libgit2_d.repository.git_repository_init_flag_t.GIT_REPOSITORY_INIT_MKPATH;

			if (o.bare) {
				initopts.flags |= libgit2_d.repository.git_repository_init_flag_t.GIT_REPOSITORY_INIT_BARE;
			}

			if (o.template_ != null) {
				initopts.flags |= libgit2_d.repository.git_repository_init_flag_t.GIT_REPOSITORY_INIT_EXTERNAL_TEMPLATE;
				initopts.template_path = o.template_;
			}

			if (o.gitdir != null) {
				/**
				 * If you specified a separate git directory, then initialize
				 * the repository at that path and use the second path as the
				 * working directory of the repository (with a git-link file)
				 */
				initopts.workdir_path = o.dir;
				o.dir = o.gitdir;
			}

			if (o.shared_ != 0) {
				initopts.mode = o.shared_;
			}

			libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_init_ext(&repo, o.dir, &initopts), "Could not initialize repository", null);
		}

		/** Print a message to stdout like "git init" does. */

		if (!o.quiet) {
			if ((o.bare) || (o.gitdir)) {
				o.dir = libgit2_d.repository.git_repository_path(repo);
			} else {
				o.dir = libgit2_d.repository.git_repository_workdir(repo);
			}

			core.stdc.stdio.printf("Initialized empty Git repository in %s\n", o.dir);
		}

		/**
		 * As an extension to the basic "git init" command, this example
		 * gives the option to create an empty initial commit.  This is
		 * mostly to demonstrate what it takes to do that, but also some
		 * people like to have that empty base commit in their repo.
		 */
		if (o.initial_commit) {
			.create_initial_commit(repo);
			core.stdc.stdio.printf("Created empty initial commit\n");
		}

		libgit2_d.repository.git_repository_free(repo);

		return 0;
	}

/**
 * Unlike regular "git init", this example shows how to create an initial
 * empty commit in the repository.  This is the helper function that does
 * that.
 */
nothrow @nogc
private void create_initial_commit(libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		libgit2_d.types.git_signature* sig;

		/** First use the config to initialize a commit signature for the user. */

		if (libgit2_d.signature.git_signature_default(&sig, repo) < 0) {
			libgit2_d.example.common.fatal("Unable to create a commit signature.", "Perhaps 'user.name' and 'user.email' are not set");
		}

		/* Now let's create an empty tree for this commit */

		libgit2_d.types.git_index* index;

		if (libgit2_d.repository.git_repository_index(&index, repo) < 0) {
			libgit2_d.example.common.fatal("Could not open repository index", null);
		}

		/**
		 * Outside of this example, you could call libgit2_d.index.git_index_add_bypath()
		 * here to put actual files into the index.  For our purposes, we'll
		 * leave it empty for now.
		 */

		libgit2_d.oid.git_oid tree_id;

		if (libgit2_d.index.git_index_write_tree(&tree_id, index) < 0) {
			libgit2_d.example.common.fatal("Unable to write initial tree from index", null);
		}

		libgit2_d.index.git_index_free(index);

		libgit2_d.types.git_tree* tree;

		if (libgit2_d.tree.git_tree_lookup(&tree, repo, &tree_id) < 0) {
			libgit2_d.example.common.fatal("Could not look up initial tree", null);
		}

		/**
		 * Ready to create the initial commit.
		 *
		 * Normally creating a commit would involve looking up the current
		 * HEAD commit and making that be the parent of the initial commit,
		 * but here this is the first commit so there will be no parent.
		 */

		libgit2_d.oid.git_oid commit_id;

		if (libgit2_d.commit.git_commit_create_v(&commit_id, repo, "HEAD", sig, sig, null, "Initial commit", tree, 0) < 0) {
			libgit2_d.example.common.fatal("Could not create the initial commit", null);
		}

		/** Clean up so we don't leak memory. */

		libgit2_d.tree.git_tree_free(tree);
		libgit2_d.signature.git_signature_free(sig);
	}

nothrow @nogc
private void usage(const (char)* error, const (char)* arg)

	in
	{
	}

	do
	{
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "error: %s '%s'\n", error, arg);

		core.stdc.stdio.fprintf(core.stdc.stdio.stderr,
			"usage: init [-q | --quiet] [--bare] [--template=<dir>]\n"
			~ "            [--shared[=perms]] [--initial-commit]\n"
			~ "            [--separate-git-dir] <directory>\n");

		core.stdc.stdlib.exit(1);
	}

/**
 * Parse the tail of the --shared= argument.
 */
nothrow @nogc
private uint parse_shared(const (char)* shared_)

	in
	{
	}

	do
	{
		if ((!core.stdc.string.strcmp(shared_, "false")) || (!core.stdc.string.strcmp(shared_, "umask"))) {
			return libgit2_d.repository.git_repository_init_mode_t.GIT_REPOSITORY_INIT_SHARED_UMASK;
		} else if ((!core.stdc.string.strcmp(shared_, "true")) || (!core.stdc.string.strcmp(shared_, "group"))) {
			return libgit2_d.repository.git_repository_init_mode_t.GIT_REPOSITORY_INIT_SHARED_GROUP;
		} else if ((!core.stdc.string.strcmp(shared_, "all")) || (!core.stdc.string.strcmp(shared_, "world")) || (!core.stdc.string.strcmp(shared_, "everybody"))) {
			return libgit2_d.repository.git_repository_init_mode_t.GIT_REPOSITORY_INIT_SHARED_ALL;
		} else if (shared_[0] == '0') {
			core.stdc.config.c_long val;
			const (char)* end = null;
			val = core.stdc.stdlib.strtol(shared_ + 1, &end, 8);

			if ((end == (shared_ + 1)) || (*end != 0)) {
				.usage("invalid octal value for --shared", shared_);
			}

			return cast(uint)(val);
		} else {
			.usage("unknown value for --shared", shared_);
		}

		return 0;
	}

nothrow @nogc
private void parse_opts(.init_opts* o, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);
		const (char)* sharedarg;

		/** Process arguments. */

		for (args.pos = 1; args.pos < argc; ++args.pos) {
			char* a = argv[args.pos];

			if (a[0] == '-') {
				o.no_options = 0;
			}

			if (a[0] != '-') {
				if (o.dir != null) {
					.usage("extra argument", a);
				}

				o.dir = a;
			} else if ((!core.stdc.string.strcmp(a, "-q")) || (!core.stdc.string.strcmp(a, "--quiet"))) {
				o.quiet = 1;
			} else if (!core.stdc.string.strcmp(a, "--bare")) {
				o.bare = 1;
			} else if (!core.stdc.string.strcmp(a, "--shared")) {
				o.shared_ = libgit2_d.repository.git_repository_init_mode_t.GIT_REPOSITORY_INIT_SHARED_GROUP;
			} else if (!core.stdc.string.strcmp(a, "--initial-commit")) {
				o.initial_commit = 1;
			} else if (libgit2_d.example.args.match_str_arg(&sharedarg, &args, "--shared")) {
				o.shared_ = .parse_shared(sharedarg);
			} else if ((!libgit2_d.example.args.match_str_arg(&o.template_, &args, "--template")) || (!libgit2_d.example.args.match_str_arg(&o.gitdir, &args, "--separate-git-dir"))) {
				.usage("unknown option", a);
			}
		}

		if (o.dir == null) {
			.usage("must specify directory to init", "");
		}
	}
