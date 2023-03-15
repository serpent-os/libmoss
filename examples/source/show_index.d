/*
 * libgit2 "showindex" example - shows how to extract data from the index
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
module libgit2_d.example.show_index;


private static import core.stdc.stdio;
private static import core.stdc.string;
private static import libgit2_d.example.common;
private static import libgit2_d.index;
private static import libgit2_d.oid;
private static import libgit2_d.repository;
private static import libgit2_d.types;

package:

extern (C)
nothrow @nogc
public int lg2_show_index(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] out_ = '\0';

		if (argc > 2) {
			libgit2_d.example.common.fatal("usage: showindex [<repo-dir>]", null);
		}

		const char* dir = (argc > 1) ? (argv[1]) : (".");
		size_t dirlen = core.stdc.string.strlen(dir);

		libgit2_d.types.git_index* index;

		if ((dirlen > 5) && (core.stdc.string.strcmp(dir + dirlen - 5, "index") == 0)) {
			libgit2_d.example.common.check_lg2(libgit2_d.index.git_index_open(&index, dir), "could not open index", dir);
		} else {
			libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_open_ext(&repo, dir, 0, null), "could not open repository", dir);
			libgit2_d.example.common.check_lg2(libgit2_d.repository.git_repository_index(&index, repo), "could not open repository index", null);
			libgit2_d.repository.git_repository_free(repo);
		}

		libgit2_d.index.git_index_read(index, 0);

		size_t ecount = libgit2_d.index.git_index_entrycount(index);

		if (!ecount) {
			core.stdc.stdio.printf("Empty index\n");
		}
	
		for (size_t i = 0; i < ecount; ++i) {
			const (libgit2_d.index.git_index_entry)* e = libgit2_d.index.git_index_get_byindex(index, i);

			libgit2_d.oid.git_oid_fmt(&(out_[0]), &e.id);

			core.stdc.stdio.printf("File Path: %s\n", e.path);
			core.stdc.stdio.printf("    Stage: %d\n", libgit2_d.index.git_index_entry_stage(e));
			core.stdc.stdio.printf(" Blob SHA: %s\n", &(out_[0]));
			core.stdc.stdio.printf("File Mode: %07o\n", e.mode);
			core.stdc.stdio.printf("File Size: %d bytes\n", cast(int)(e.file_size));
			core.stdc.stdio.printf("Dev/Inode: %d/%d\n", cast(int)(e.dev), cast(int)(e.ino));
			core.stdc.stdio.printf("  UID/GID: %d/%d\n", cast(int)(e.uid), cast(int)(e.gid));
			core.stdc.stdio.printf("    ctime: %d\n", cast(int)(e.ctime.seconds));
			core.stdc.stdio.printf("    mtime: %d\n", cast(int)(e.mtime.seconds));
			core.stdc.stdio.printf("\n");
		}

		libgit2_d.index.git_index_free(index);

		return 0;
	}
