/*
 * libgit2 "rev-list" example - shows how to transform a rev-spec into a list
 * of commit ids
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
module libgit2_d.example.rev_list;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.errors;
private static import libgit2_d.example.args;
private static import libgit2_d.example.common;
private static import libgit2_d.object;
private static import libgit2_d.oid;
private static import libgit2_d.revparse;
private static import libgit2_d.revwalk;
private static import libgit2_d.types;

package:

//private int revwalk_parseopts(libgit2_d.types.git_repository* repo, libgit2_d.types.git_revwalk* walk, int nopts, char** opts);

extern (C)
nothrow @nogc
public int lg2_rev_list(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);
		libgit2_d.types.git_revwalk* walk;
		libgit2_d.revwalk.git_sort_t sort;

		libgit2_d.example.common.check_lg2(.revwalk_parse_options(&sort, &args), "parsing options", null);

		libgit2_d.example.common.check_lg2(libgit2_d.revwalk.git_revwalk_new(&walk, repo), "allocating revwalk", null);
		libgit2_d.revwalk.git_revwalk_sorting(walk, sort);
		libgit2_d.example.common.check_lg2(.revwalk_parse_revs(repo, walk, &args), "parsing revs", null);

		libgit2_d.oid.git_oid oid;
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] buf;

		while (!libgit2_d.revwalk.git_revwalk_next(&oid, walk)) {
			libgit2_d.oid.git_oid_fmt(&(buf[0]), &oid);
			buf[libgit2_d.oid.GIT_OID_HEXSZ] = '\0';
			core.stdc.stdio.printf("%s\n", &(buf[0]));
		}

		libgit2_d.revwalk.git_revwalk_free(walk);

		return 0;
	}

nothrow @nogc
private int push_commit(libgit2_d.types.git_revwalk* walk, const (libgit2_d.oid.git_oid)* oid, int hide)

	in
	{
	}

	do
	{
		if (hide) {
			return libgit2_d.revwalk.git_revwalk_hide(walk, oid);
		} else {
			return libgit2_d.revwalk.git_revwalk_push(walk, oid);
		}
	}

nothrow @nogc
private int push_spec(libgit2_d.types.git_repository* repo, libgit2_d.types.git_revwalk* walk, const (char)* spec, int hide)

	in
	{
	}

	do
	{
		libgit2_d.types.git_object* obj;
		int error = libgit2_d.revparse.git_revparse_single(&obj, repo, spec);

		if (error < 0) {
			return error;
		}

		error = .push_commit(walk, libgit2_d.object.git_object_id(obj), hide);
		libgit2_d.object.git_object_free(obj);

		return error;
	}

nothrow @nogc
private int push_range(libgit2_d.types.git_repository* repo, libgit2_d.types.git_revwalk* walk, const (char)* range, int hide)

	in
	{
	}

	do
	{
		libgit2_d.revparse.git_revspec revspec;
		int error = libgit2_d.revparse.git_revparse(&revspec, repo, range);

		if (error) {
			return error;
		}

		scope (exit) {
			libgit2_d.object.git_object_free(revspec.from);
			libgit2_d.object.git_object_free(revspec.to);
		}

		if (revspec.flags & libgit2_d.revparse.git_revparse_mode_t.GIT_REVPARSE_MERGE_BASE) {
			/* TODO: support "<commit>...<commit>" */
			return libgit2_d.errors.git_error_code.GIT_EINVALIDSPEC;
		}

		error = .push_commit(walk, libgit2_d.object.git_object_id(revspec.from), !hide);

		if (error) {
			return error;
		}

		error = .push_commit(walk, libgit2_d.object.git_object_id(revspec.to), hide);

		return error;
	}

nothrow @nogc
private void print_usage()

	do
	{
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "rev-list [--git-dir=dir] [--topo-order|--date-order] [--reverse] <revspec>\n");
		core.stdc.stdlib.exit(-1);
	}

nothrow @nogc
private int revwalk_parse_options(libgit2_d.revwalk.git_sort_t* sort, libgit2_d.example.args.args_info* args)

	in
	{
		assert((sort) && (args));
	}

	do
	{
		*sort = libgit2_d.revwalk.git_sort_t.GIT_SORT_NONE;

		if (args.argc < 1) {
			.print_usage();
		}

		for (args.pos = 1; args.pos < args.argc; ++args.pos) {
			const (char)* curr = args.argv[args.pos];

			if (!core.stdc.string.strcmp(curr, "--topo-order")) {
				*sort |= libgit2_d.revwalk.git_sort_t.GIT_SORT_TOPOLOGICAL;
			} else if (!core.stdc.string.strcmp(curr, "--date-order")) {
				*sort |= libgit2_d.revwalk.git_sort_t.GIT_SORT_TIME;
			} else if (!core.stdc.string.strcmp(curr, "--reverse")) {
				*sort |= (*sort & ~libgit2_d.revwalk.git_sort_t.GIT_SORT_REVERSE) ^ libgit2_d.revwalk.git_sort_t.GIT_SORT_REVERSE;
			} else {
				break;
			}
		}

		return 0;
	}

nothrow @nogc
private int revwalk_parse_revs(libgit2_d.types.git_repository* repo, libgit2_d.types.git_revwalk* walk, libgit2_d.example.args.args_info* args)

	in
	{
	}

	do
	{
		int hide = 0;
		int error;
		libgit2_d.oid.git_oid oid;

		for (; args.pos < args.argc; ++args.pos) {
			const (char)* curr = args.argv[args.pos];

			if (!core.stdc.string.strcmp(curr, "--not")) {
				hide = !hide;
			} else if (curr[0] == '^') {
				error = .push_spec(repo, walk, curr + 1, !hide);

				if (error) {
					return error;
				}
			} else if (core.stdc.string.strstr(curr, "..")) {
				error = .push_range(repo, walk, curr, hide);

				if (error) {
					return error;
				}
			} else {
				if (.push_spec(repo, walk, curr, hide) == 0) {
					continue;
				}

				error = libgit2_d.oid.git_oid_fromstr(&oid, curr);

				if (error) {
					return error;
				}

				error = .push_commit(walk, &oid, hide);

				if (error) {
					return error;
				}
			}
		}

		return 0;
	}
