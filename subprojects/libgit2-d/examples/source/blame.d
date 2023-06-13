/*
 * libgit2 "blame" example - shows how to use the blame API
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
module libgit2_d.example.blame;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.blame;
private static import libgit2_d.blob;
private static import libgit2_d.example.common;
private static import libgit2_d.object;
private static import libgit2_d.oid;
private static import libgit2_d.revparse;
private static import libgit2_d.types;
private static import std.ascii;

package:

/**
 * This example demonstrates how to invoke the libgit2 blame API to roughly
 * simulate the output of `git blame` and a few of its command line arguments.
 */

public struct blame_opts
{
	char* path;
	char* commitspec;
	int C;
	int M;
	int start_line;
	int end_line;
	int F;
}

extern (C)
nothrow @nogc
//int lg2_blame(libgit2_d.types.git_repository* repo, int argc, char*[] argv)
public int lg2_blame(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		.blame_opts o = .blame_opts.init;
		.parse_opts(&o, argc, argv);

		libgit2_d.blame.git_blame_options blameopts = libgit2_d.blame.GIT_BLAME_OPTIONS_INIT();

		if (o.M) {
			blameopts.flags |= libgit2_d.blame.git_blame_flag_t.GIT_BLAME_TRACK_COPIES_SAME_COMMIT_MOVES;
		}

		if (o.C) {
			blameopts.flags |= libgit2_d.blame.git_blame_flag_t.GIT_BLAME_TRACK_COPIES_SAME_COMMIT_COPIES;
		}

		if (o.F) {
			blameopts.flags |= libgit2_d.blame.git_blame_flag_t.GIT_BLAME_FIRST_PARENT;
		}

		libgit2_d.revparse.git_revspec revspec = libgit2_d.revparse.git_revspec.init;

		/**
		 * The commit range comes in "commitish" form. Use the rev-parse API to
		 * nail down the end points.
		 */
		if (o.commitspec != null) {
			libgit2_d.example.common.check_lg2(libgit2_d.revparse.git_revparse(&revspec, repo, o.commitspec), "Couldn't parse commit spec", null);

			if (revspec.flags & libgit2_d.revparse.git_revparse_mode_t.GIT_REVPARSE_SINGLE) {
				libgit2_d.oid.git_oid_cpy(&blameopts.newest_commit, libgit2_d.object.git_object_id(revspec.from));
				libgit2_d.object.git_object_free(revspec.from);
			} else {
				libgit2_d.oid.git_oid_cpy(&blameopts.oldest_commit, libgit2_d.object.git_object_id(revspec.from));
				libgit2_d.oid.git_oid_cpy(&blameopts.newest_commit, libgit2_d.object.git_object_id(revspec.to));
				libgit2_d.object.git_object_free(revspec.from);
				libgit2_d.object.git_object_free(revspec.to);
			}
		}

		/** Run the blame. */
		libgit2_d.blame.git_blame* blame = null;
		libgit2_d.example.common.check_lg2(libgit2_d.blame.git_blame_file(&blame, repo, o.path, &blameopts), "Blame error", null);

		char[1024] spec  = '\0';

		/**
		 * Get the raw data inside the blob for output. We use the
		 * `commitish:path/to/file.txt` format to find it.
		 */
		if (libgit2_d.oid.git_oid_is_zero(&blameopts.newest_commit)) {
			core.stdc.string.strcpy(&(spec[0]), "HEAD");
		} else {
			libgit2_d.oid.git_oid_tostr(&(spec[0]), spec.length, &blameopts.newest_commit);
		}

		core.stdc.string.strcat(&(spec[0]), ":");
		core.stdc.string.strcat(&(spec[0]), o.path);

		libgit2_d.types.git_object* obj;
		libgit2_d.example.common.check_lg2(libgit2_d.revparse.git_revparse_single(&obj, repo, &(spec[0])), "Object lookup error", null);
		libgit2_d.types.git_blob* blob;
		libgit2_d.example.common.check_lg2(libgit2_d.blob.git_blob_lookup(&blob, repo, libgit2_d.object.git_object_id(obj)), "Blob lookup error", null);
		libgit2_d.object.git_object_free(obj);

		const char* rawdata = cast(const char*)(libgit2_d.blob.git_blob_rawcontent(blob));
		libgit2_d.types.git_object_size_t rawsize = libgit2_d.blob.git_blob_rawsize(blob);

		/** Produce the output. */
		int line = 1;
		libgit2_d.types.git_object_size_t i = 0;
		int break_on_null_hunk = 0;

		while (i < rawsize) {
			const char* eol = cast(const char*)(core.stdc.string.memchr(rawdata + i, '\n', cast(size_t)(rawsize - i)));
			char[10] oid  = '\0';
			const (libgit2_d.blame.git_blame_hunk)* hunk = libgit2_d.blame.git_blame_get_hunk_byline(blame, line);

			if ((break_on_null_hunk) && (!hunk)) {
				break;
			}

			if (hunk != null) {
				char[128] sig  = '\0';
				break_on_null_hunk = 1;

				libgit2_d.oid.git_oid_tostr(&(oid[0]), 10, &hunk.final_commit_id);
				libgit2_d.example.common.snprintf(&(sig[0]), 30, "%s <%s>", hunk.final_signature.name, hunk.final_signature.email);

				core.stdc.stdio.printf("%s ( %-30s %3d) %.*s\n", &(oid[0]), &(sig[0]), line, cast(int)(eol - rawdata - i), rawdata + i);
			}

			i = cast(int)(eol - rawdata + 1);
			line++;
		}

		/** Cleanup. */
		libgit2_d.blob.git_blob_free(blob);
		libgit2_d.blame.git_blame_free(blame);

		return 0;
	}

/**
 * Tell the user how to make this thing work.
 */
nothrow @nogc
private void usage(const (char)* msg, const (char)* arg)

	in
	{
	}

	do
	{
		if ((msg != null) && (arg != null)) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "%s: %s\n", msg, arg);
		} else if (msg != null) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "%s\n", msg);
		}

		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: blame [options] [<commit range>] <path>\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "   <commit range>      example: `HEAD~10..HEAD`, or `1234abcd`\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "   -L <n,m>            process only line range n-m, counting from 1\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "   -M                  find line moves within and across files\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "   -C                  find line copies within and across files\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "   -F                  follow only the first parent commits\n");
		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "\n");
		core.stdc.stdlib.exit(1);
	}

pragma(inline, true)
pure nothrow @trusted @nogc
private bool is_option(const char* input, char c1, char c2)

	in
	{
		assert(input != null);
		assert(c1 != c2);
		assert(std.ascii.isUpper(c1));
		assert(std.ascii.isLower(c2));
		assert(c1 == std.ascii.toUpper(c2));
	}

	do
	{
		return (*input == '-') && ((*(input + 1) == c1) || (*(input + 1) == c2));
	}

/**
 * Parse the arguments.
 */
nothrow @nogc
private void parse_opts(.blame_opts* o, int argc, char** argv)

	in
	{
	}

	do
	{
		char*[3] bare_args = null;

		if (argc < 2) {
			.usage(null, null);
		}

		for (int i = 1; i < argc; i++) {
			char* a = argv[i];

			if (a[0] != '-') {
				i = 0;

				while ((bare_args[i]) && (i < 3)) {
					++i;
				}

				if (i >= 3) {
					.usage("Invalid argument set", null);
				}

				bare_args[i] = a;
			} else if (!core.stdc.string.strcmp(a, "--")) {
				continue;
			} else if (.is_option(a, 'M', 'm')) {
				o.M = 1;
			} else if (.is_option(a, 'C', 'c')) {
				o.C = 1;
			} else if (.is_option(a, 'F', 'f')) {
				o.F = 1;
			} else if (.is_option(a, 'L', 'l')) {
				i++;
				a = argv[i];

				if (i >= argc) {
					libgit2_d.example.common.fatal("Not enough arguments to -L", null);
				}

				libgit2_d.example.common.check_lg2(core.stdc.stdio.sscanf(a, "%d,%d", &o.start_line, &o.end_line) - 2, "-L format error", null);
			} else {
				/* commit range */
				if (o.commitspec) {
					libgit2_d.example.common.fatal("Only one commit spec allowed", null);
				}

				o.commitspec = a;
			}
		}

		/* Handle the bare arguments */
		if (!bare_args[0]) {
			.usage("Please specify a path", null);
		}

		o.path = bare_args[0];

		if (bare_args[1]) {
			/* <commitspec> <path> */
			o.path = bare_args[1];
			o.commitspec = bare_args[0];
		}

		if (bare_args[2]) {
			/* <oldcommit> <newcommit> <path> */
			char[128] spec  = '\0';
			o.path = bare_args[2];
			core.stdc.stdio.sprintf(&(spec[0]), "%s..%s", bare_args[0], bare_args[1]);
			o.commitspec = &(spec[0]);
		}
	}
