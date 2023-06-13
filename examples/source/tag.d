/*
 * libgit2 "tag" example - shows how to list, create and delete tags
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
module libgit2_d.example.tag;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.buffer;
private static import libgit2_d.commit;
private static import libgit2_d.example.args;
private static import libgit2_d.example.common;
private static import libgit2_d.object;
private static import libgit2_d.oid;
private static import libgit2_d.revparse;
private static import libgit2_d.signature;
private static import libgit2_d.strarray;
private static import libgit2_d.tag;
private static import libgit2_d.types;

package:

/**
 * The following example partially reimplements the `git tag` command
 * and some of its options.
 *
 * These commands should work:
 *
 * - Tag name listing (`tag`)
 * - Filtered tag listing with messages (`tag -n3 -l "v0.1*"`)
 * - Lightweight tag creation (`tag test v0.18.0`)
 * - Tag creation (`tag -a -m "Test message" test v0.18.0`)
 * - Tag deletion (`tag -d test`)
 *
 * The command line parsing logic is simplified and doesn't handle
 * all of the use cases.
 */

/**
 * tag_options represents the parsed command line options
 */
public struct tag_options
{
	const (char)* message;
	const (char)* pattern;
	const (char)* tag_name;
	const (char)* target;
	int num_lines;
	int force;
}

/**
 * tag_state represents the current program state for dragging around
 */
public struct tag_state
{
	libgit2_d.types.git_repository* repo;
	.tag_options* opts;
}

/**
 * An action to execute based on the command line arguments
 */
public alias tag_action = nothrow @nogc void function(.tag_state* state);

nothrow @nogc
private void check(int result, const (char)* message)

	in
	{
	}

	do
	{
		if (result) {
			libgit2_d.example.common.fatal(message, null);
		}
	}

/**
 * Tag listing: Print individual message lines
 */
nothrow @nogc
private void print_list_lines(const (char)* message, const (.tag_state)* state)

	in
	{
	}

	do
	{
		const (char)* msg = message;
		int num = state.opts.num_lines - 1;

		if (msg == null) {
			return;
		}

		/** first line - headline */
		while ((*msg) && (*msg != '\n')) {
			core.stdc.stdio.printf("%c", *msg++);
		}

		/** skip over new lines */
		while ((*msg) && (*msg == '\n')) {
			msg++;
		}

		core.stdc.stdio.printf("\n");

		/** print just headline? */
		if (num == 0) {
			return;
		}

		if ((*msg) && (msg[1])) {
			core.stdc.stdio.printf("\n");
		}

		/** print individual commit/tag lines */
		while ((*msg) && (num-- >= 2)) {
			core.stdc.stdio.printf("    ");

			while ((*msg) && (*msg != '\n')) {
				core.stdc.stdio.printf("%c", *msg++);
			}

			/** handle consecutive new lines */
			if ((*msg) && (*msg == '\n') && (msg[1] == '\n')) {
				num--;
				core.stdc.stdio.printf("\n");
			}

			while ((*msg) && (*msg == '\n')) {
				msg++;
			}

			core.stdc.stdio.printf("\n");
		}
	}

/**
 * Tag listing: Print an actual tag object
 */
nothrow @nogc
private void print_tag(libgit2_d.types.git_tag* tag, const (.tag_state)* state)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("%-16s", libgit2_d.tag.git_tag_name(tag));

		if (state.opts.num_lines) {
			const (char)* msg = libgit2_d.tag.git_tag_message(tag);
			.print_list_lines(msg, state);
		} else {
			core.stdc.stdio.printf("\n");
		}
	}

/**
 * Tag listing: Print a commit (target of a lightweight tag)
 */
nothrow @nogc
private void print_commit(libgit2_d.types.git_commit* commit, const (char)* name, const (.tag_state)* state)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("%-16s", name);

		if (state.opts.num_lines) {
			const (char)* msg = libgit2_d.commit.git_commit_message(commit);
			.print_list_lines(msg, state);
		} else {
			core.stdc.stdio.printf("\n");
		}
	}

/**
 * Tag listing: Fallback, should not happen
 */
nothrow @nogc
private void print_name(const (char)* name)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("%s\n", name);
	}

/**
 * Tag listing: Lookup tags based on ref name and dispatch to print
 */
nothrow @nogc
private int each_tag(const (char)* name, .tag_state* state)

	in
	{
	}

	do
	{
		libgit2_d.types.git_repository* repo = state.repo;
		libgit2_d.types.git_object* obj;

		libgit2_d.example.common.check_lg2(libgit2_d.revparse.git_revparse_single(&obj, repo, name), "Failed to lookup rev", name);

		switch (libgit2_d.object.git_object_type(obj)) {
			case libgit2_d.types.git_object_t.GIT_OBJECT_TAG:
				.print_tag(cast(libgit2_d.types.git_tag*)(obj), state);

				break;

			case libgit2_d.types.git_object_t.GIT_OBJECT_COMMIT:
				.print_commit(cast(libgit2_d.types.git_commit*)(obj), name, state);

				break;

			default:
				.print_name(name);

				break;
		}

		libgit2_d.object.git_object_free(obj);

		return 0;
	}

nothrow @nogc
private void action_list_tags(.tag_state* state)

	in
	{
	}

	do
	{
		const (char)* pattern = state.opts.pattern;
		libgit2_d.strarray.git_strarray tag_names = libgit2_d.strarray.git_strarray.init;

		libgit2_d.example.common.check_lg2(libgit2_d.tag.git_tag_list_match(&tag_names, (pattern) ? (pattern) : ("*"), state.repo), "Unable to get list of tags", null);

		for (size_t i = 0; i < tag_names.count; i++) {
			.each_tag(tag_names.strings[i], state);
		}

		libgit2_d.strarray.git_strarray_dispose(&tag_names);
	}

nothrow @nogc
private void action_delete_tag(.tag_state* state)

	in
	{
	}

	do
	{
		.tag_options* opts = state.opts;
		libgit2_d.types.git_object* obj;
		libgit2_d.buffer.git_buf abbrev_oid = libgit2_d.buffer.git_buf.init;

		.check(!opts.tag_name, "Name required");

		libgit2_d.example.common.check_lg2(libgit2_d.revparse.git_revparse_single(&obj, state.repo, opts.tag_name), "Failed to lookup rev", opts.tag_name);

		libgit2_d.example.common.check_lg2(libgit2_d.object.git_object_short_id(&abbrev_oid, obj), "Unable to get abbreviated OID", opts.tag_name);

		libgit2_d.example.common.check_lg2(libgit2_d.tag.git_tag_delete(state.repo, opts.tag_name), "Unable to delete tag", opts.tag_name);

		core.stdc.stdio.printf("Deleted tag '%s' (was %s)\n", opts.tag_name, abbrev_oid.ptr_);

		libgit2_d.buffer.git_buf_dispose(&abbrev_oid);
		libgit2_d.object.git_object_free(obj);
	}

nothrow @nogc
private void action_create_lighweight_tag(.tag_state* state)

	in
	{
	}

	do
	{
		libgit2_d.types.git_repository* repo = state.repo;
		.tag_options* opts = state.opts;

		.check(!opts.tag_name, "Name required");

		if (opts.target == null) {
			opts.target = "HEAD";
		}

		.check(!opts.target, "Target required");

		libgit2_d.types.git_object* target;
		libgit2_d.example.common.check_lg2(libgit2_d.revparse.git_revparse_single(&target, repo, opts.target), "Unable to resolve spec", opts.target);

		libgit2_d.oid.git_oid oid;
		libgit2_d.example.common.check_lg2(libgit2_d.tag.git_tag_create_lightweight(&oid, repo, opts.tag_name, target, opts.force), "Unable to create tag", null);

		libgit2_d.object.git_object_free(target);
	}

nothrow @nogc
private void action_create_tag(.tag_state* state)

	in
	{
	}

	do
	{
		libgit2_d.types.git_repository* repo = state.repo;
		.tag_options* opts = state.opts;

		.check(!opts.tag_name, "Name required");
		.check(!opts.message, "Message required");

		if (opts.target == null) {
			opts.target = "HEAD";
		}

		libgit2_d.types.git_object* target;
		libgit2_d.example.common.check_lg2(libgit2_d.revparse.git_revparse_single(&target, repo, opts.target), "Unable to resolve spec", opts.target);

		libgit2_d.types.git_signature* tagger;
		libgit2_d.example.common.check_lg2(libgit2_d.signature.git_signature_default(&tagger, repo), "Unable to create signature", null);

		libgit2_d.oid.git_oid oid;
		libgit2_d.example.common.check_lg2(libgit2_d.tag.git_tag_create(&oid, repo, opts.tag_name, target, tagger, opts.message, opts.force), "Unable to create tag", null);

		libgit2_d.object.git_object_free(target);
		libgit2_d.signature.git_signature_free(tagger);
	}

nothrow @nogc
private void print_usage()

	in
	{
	}

	do
	{
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: see `git help tag`\n");
		core.stdc.stdlib.exit(1);
	}

/**
 * Parse command line arguments and choose action to run when done
 */
nothrow @nogc
private void parse_options(.tag_action* action, .tag_options* opts, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);
		*action = &.action_list_tags;

		for (args.pos = 1; args.pos < argc; ++args.pos) {
			const (char)* curr = argv[args.pos];

			if (curr[0] != '-') {
				if (opts.tag_name == null) {
					opts.tag_name = curr;
				} else if (opts.target == null) {
					opts.target = curr;
				} else {
					.print_usage();
				}

				if (*action != &.action_create_tag) {
					*action = &.action_create_lighweight_tag;
				}
			} else if (!core.stdc.string.strcmp(curr, "-n")) {
				opts.num_lines = 1;
				*action = &.action_list_tags;
			} else if (!core.stdc.string.strcmp(curr, "-a")) {
				*action = &.action_create_tag;
			} else if (!core.stdc.string.strcmp(curr, "-f")) {
				opts.force = 1;
			} else if (libgit2_d.example.args.match_int_arg(&opts.num_lines, &args, "-n", 0)) {
				*action = &.action_list_tags;
			} else if (libgit2_d.example.args.match_str_arg(&opts.pattern, &args, "-l")) {
				*action = &.action_list_tags;
			} else if (libgit2_d.example.args.match_str_arg(&opts.tag_name, &args, "-d")) {
				*action = &.action_delete_tag;
			} else if (libgit2_d.example.args.match_str_arg(&opts.message, &args, "-m")) {
				*action = &.action_create_tag;
			}
		}
	}

/**
 * Initialize tag_options struct
 */
nothrow @nogc
private void tag_options_init(.tag_options* opts)

	in
	{
	}

	do
	{
		core.stdc.string.memset(opts, 0, (*opts).sizeof);

		opts.message = null;
		opts.pattern = null;
		opts.tag_name = null;
		opts.target = null;
		opts.num_lines = 0;
		opts.force = 0;
	}

extern (C)
nothrow @nogc
public int lg2_tag(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		.tag_options opts;
		.tag_options_init(&opts);
		.tag_action action;
		.parse_options(&action, &opts, argc, argv);

		.tag_state state =
		{
			repo: repo,
			opts: &opts,
		};

		action(&state);

		return 0;
	}
