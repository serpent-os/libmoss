/*
 * libgit2 "cat-file" example - shows how to print data from the ODB
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
module libgit2_d.example.cat_file;


private static import core.stdc.config;
private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.blob;
private static import libgit2_d.commit;
private static import libgit2_d.example.args;
private static import libgit2_d.example.common;
private static import libgit2_d.object;
private static import libgit2_d.odb;
private static import libgit2_d.oid;
private static import libgit2_d.repository;
private static import libgit2_d.revparse;
private static import libgit2_d.tag;
private static import libgit2_d.tree;
private static import libgit2_d.types;

package:

nothrow @nogc
private void print_signature(const (char)* header, const (libgit2_d.types.git_signature)* sig)

	in
	{
	}

	do
	{
		if (sig == null) {
			return;
		}

		int offset = sig.when.offset;
		char sign;

		if (offset < 0) {
			sign = '-';
			offset = -offset;
		} else {
			sign = '+';
		}

		int hours = offset / 60;
		int minutes = offset % 60;

		core.stdc.stdio.printf("%s %s <%s> %ld %c%02d%02d\n", header, sig.name, sig.email, cast(core.stdc.config.c_long)(sig.when.time), sign, hours, minutes);
	}

/**
 * Printing out a blob is simple, get the contents and print
 */
nothrow @nogc
private void show_blob(const (libgit2_d.types.git_blob)* blob)

	in
	{
	}

	do
	{
		/* ? Does this need crlf filtering? */
		core.stdc.stdio.fwrite(libgit2_d.blob.git_blob_rawcontent(blob), cast(size_t)(libgit2_d.blob.git_blob_rawsize(blob)), 1, core.stdc.stdio.stdout);
	}

/**
 * Show each entry with its type, id and attributes
 */
nothrow @nogc
private void show_tree(const (libgit2_d.types.git_tree)* tree)

	in
	{
	}

	do
	{
		size_t max_i = cast(int)(libgit2_d.tree.git_tree_entrycount(tree));
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] oidstr;

		for (size_t i = 0; i < max_i; ++i) {
			const (libgit2_d.types.git_tree_entry)* te = libgit2_d.tree.git_tree_entry_byindex(tree, i);

			libgit2_d.oid.git_oid_tostr(&(oidstr[0]), oidstr.length, libgit2_d.tree.git_tree_entry_id(te));

			core.stdc.stdio.printf("%06o %s %s\t%s\n", libgit2_d.tree.git_tree_entry_filemode(te), libgit2_d.object.git_object_type2string(libgit2_d.tree.git_tree_entry_type(te)), &(oidstr[0]), libgit2_d.tree.git_tree_entry_name(te));
		}
	}

/**
 * Commits and tags have a few interesting fields in their header.
 */
nothrow @nogc
private void show_commit(const (libgit2_d.types.git_commit)* commit)

	in
	{
	}

	do
	{
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] oidstr;
		libgit2_d.oid.git_oid_tostr(&(oidstr[0]), oidstr.length, libgit2_d.commit.git_commit_tree_id(commit));
		core.stdc.stdio.printf("tree %s\n", &(oidstr[0]));

		uint max_i = cast(uint)(libgit2_d.commit.git_commit_parentcount(commit));

		for (uint i = 0; i < max_i; ++i) {
			libgit2_d.oid.git_oid_tostr(&(oidstr[0]), oidstr.length, libgit2_d.commit.git_commit_parent_id(commit, i));
			core.stdc.stdio.printf("parent %s\n", &(oidstr[0]));
		}

		.print_signature("author", libgit2_d.commit.git_commit_author(commit));
		.print_signature("committer", libgit2_d.commit.git_commit_committer(commit));

		if (libgit2_d.commit.git_commit_message(commit)) {
			core.stdc.stdio.printf("\n%s\n", libgit2_d.commit.git_commit_message(commit));
		}
	}

nothrow @nogc
private void show_tag(const (libgit2_d.types.git_tag)* tag)

	in
	{
	}

	do
	{
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] oidstr;
		libgit2_d.oid.git_oid_tostr(&(oidstr[0]), oidstr.length, libgit2_d.tag.git_tag_target_id(tag));

		core.stdc.stdio.printf("object %s\n", &(oidstr[0]));
		core.stdc.stdio.printf("type %s\n", libgit2_d.object.git_object_type2string(libgit2_d.tag.git_tag_target_type(tag)));
		core.stdc.stdio.printf("tag %s\n", libgit2_d.tag.git_tag_name(tag));
		.print_signature("tagger", libgit2_d.tag.git_tag_tagger(tag));

		if (libgit2_d.tag.git_tag_message(tag)) {
			core.stdc.stdio.printf("\n%s\n", libgit2_d.tag.git_tag_message(tag));
		}
	}

public enum catfile_mode
{
	SHOW_TYPE = 1,
	SHOW_SIZE = 2,
	SHOW_NONE = 3,
	SHOW_PRETTY = 4,
}

//Declaration name in C language
public enum
{
	SHOW_TYPE = .catfile_mode.SHOW_TYPE,
	SHOW_SIZE = .catfile_mode.SHOW_SIZE,
	SHOW_NONE = .catfile_mode.SHOW_NONE,
	SHOW_PRETTY = .catfile_mode.SHOW_PRETTY,
}

/**
 * Forward declarations for option-parsing helper
 */
public struct catfile_options
{
	const (char)* dir;
	const (char)* rev;
	.catfile_mode action = cast(.catfile_mode)(0);
	int verbose;
}

/**
 * Entry point for this command
 */
extern (C)
nothrow @nogc
//int lg2_cat_file(libgit2_d.types.git_repository* repo, int argc, char*[] argv)
public int lg2_cat_file(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		.catfile_options o = {".", null, 0, 0};

		.parse_opts(&o, argc, argv);

		libgit2_d.types.git_object* obj = null;
		libgit2_d.example.common.check_lg2(libgit2_d.revparse.git_revparse_single(&obj, repo, o.rev), "Could not resolve", o.rev);

		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] oidstr;

		if (o.verbose) {
			libgit2_d.oid.git_oid_tostr(&(oidstr[0]), oidstr.length, libgit2_d.object.git_object_id(obj));

			core.stdc.stdio.printf("%s %s\n--\n", libgit2_d.object.git_object_type2string(libgit2_d.object.git_object_type(obj)), &(oidstr[0]));
		}

		switch (o.action) {
			case .catfile_mode.SHOW_TYPE:
				core.stdc.stdio.printf("%s\n", libgit2_d.object.git_object_type2string(libgit2_d.object.git_object_type(obj)));

				break;

			case .catfile_mode.SHOW_SIZE:
				libgit2_d.types.git_odb* odb;
				libgit2_d.types.git_odb_object* odbobj;

				libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_odb(&odb, repo), "Could not open ODB", null);
				libgit2_d.example.common.check_lg2(libgit2_d.odb.git_odb_read(&odbobj, odb, libgit2_d.object.git_object_id(obj)), "Could not find obj", null);

				core.stdc.stdio.printf("%ld\n", cast(core.stdc.config.c_long)(libgit2_d.odb.git_odb_object_size(odbobj)));

				libgit2_d.odb.git_odb_object_free(odbobj);
				libgit2_d.odb.git_odb_free(odb);

				break;

			case .catfile_mode.SHOW_NONE:
				/* just want return result */
				break;

			case .catfile_mode.SHOW_PRETTY:
				switch (libgit2_d.object.git_object_type(obj)) {
					case libgit2_d.types.git_object_t.GIT_OBJECT_BLOB:
						.show_blob(cast(const (libgit2_d.types.git_blob)*)(obj));

						break;

					case libgit2_d.types.git_object_t.GIT_OBJECT_COMMIT:
						.show_commit(cast(const (libgit2_d.types.git_commit)*)(obj));

						break;

					case libgit2_d.types.git_object_t.GIT_OBJECT_TREE:
						.show_tree(cast(const (libgit2_d.types.git_tree)*)(obj));

						break;

					case libgit2_d.types.git_object_t.GIT_OBJECT_TAG:
						.show_tag(cast(const (libgit2_d.types.git_tag)*)(obj));

						break;

					default:
						core.stdc.stdio.printf("unknown %s\n", &(oidstr[0]));

						break;
				}

				break;

			default:
				break;
		}

		libgit2_d.object.git_object_free(obj);

		return 0;
	}

/**
 * Print out usage information
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

		core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: cat-file (-t | -s | -e | -p) [-v] [-q] [-h|--help] [--git-dir=<dir>] <object>\n");
		core.stdc.stdlib.exit(1);
	}

/**
 * Parse the command-line options taken from git
 */
nothrow @nogc
private void parse_opts(.catfile_options* o, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.example.args.args_info args = libgit2_d.example.args.ARGS_INFO_INIT(argc, argv);

		for (args.pos = 1; args.pos < argc; ++args.pos) {
			char* a = argv[args.pos];

			if (a[0] != '-') {
				if (o.rev != null) {
					.usage("Only one rev should be provided", null);
				} else {
					o.rev = a;
				}
			} else if (!core.stdc.string.strcmp(a, "-t")) {
				o.action = .catfile_mode.SHOW_TYPE;
			} else if (!core.stdc.string.strcmp(a, "-s")) {
				o.action = .catfile_mode.SHOW_SIZE;
			} else if (!core.stdc.string.strcmp(a, "-e")) {
				o.action = .catfile_mode.SHOW_NONE;
			} else if (!core.stdc.string.strcmp(a, "-p")) {
				o.action = .catfile_mode.SHOW_PRETTY;
			} else if (!core.stdc.string.strcmp(a, "-q")) {
				o.verbose = 0;
			} else if (!core.stdc.string.strcmp(a, "-v")) {
				o.verbose = 1;
			} else if ((!core.stdc.string.strcmp(a, "--help")) || (!core.stdc.string.strcmp(a, "-h"))) {
				.usage(null, null);
			} else if (!libgit2_d.example.args.match_str_arg(&o.dir, &args, "--git-dir")) {
				.usage("Unknown option", a);
			}
		}

		if ((!o.action) || (!o.rev)) {
			.usage(null, null);
		}
	}
