module libgit2_d.example.index_pack;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import libgit2_d.example.common;
private static import libgit2_d.indexer;
private static import libgit2_d.oid;
private static import libgit2_d.types;

package:

/*
 * This could be run in the main loop whilst the application waits for
 * the indexing to finish in a worker thread
 */
nothrow @nogc
private int index_cb(const (libgit2_d.indexer.git_indexer_progress)* stats, void* data)

	in
	{
	}

	do
	{
		//cast(void)(data);
		core.stdc.stdio.printf("\rProcessing %u of %u", stats.indexed_objects, stats.total_objects);

		return 0;
	}

extern (C)
nothrow @nogc
public int lg2_index_pack(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		//cast(void)(repo);

		if (argc < 2) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: %s index-pack <packfile>\n", argv[-1]);

			return core.stdc.stdlib.EXIT_FAILURE;
		}

		libgit2_d.indexer.git_indexer* idx = null;

		if (libgit2_d.indexer.git_indexer_new(&idx, ".", 0, null, null) < 0) {
			core.stdc.stdio.puts("bad idx");

			return -1;
		}

		int fd = libgit2_d.example.common.open(argv[1], 0);

		if (fd < 0) {
			core.stdc.stdio.perror("open");

			return -1;
		}

		libgit2_d.indexer.git_indexer_progress stats = {0, 0};
		int error;
		libgit2_d.example.common.ssize_t read_bytes;
		char[512] buf;

		scope (exit) {
			libgit2_d.example.common.close(fd);
			libgit2_d.indexer.git_indexer_free(idx);
		}

		do {
			read_bytes = libgit2_d.example.common.read(fd, &(buf[0]), buf.length);

			if (read_bytes < 0) {
				break;
			}

			error = libgit2_d.indexer.git_indexer_append(idx, &(buf[0]), read_bytes, &stats);

			if (error < 0) {
				return error;
			}

			.index_cb(&stats, null);
		} while (read_bytes > 0);

		if (read_bytes < 0) {
			error = -1;
			core.stdc.stdio.perror("failed reading");

			return error;
		}

		error = libgit2_d.indexer.git_indexer_commit(idx, &stats);

		if (error < 0) {
			return error;
		}

		core.stdc.stdio.printf("\rIndexing %u of %u\n", stats.indexed_objects, stats.total_objects);

		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] hash  = '\0';
		libgit2_d.oid.git_oid_fmt(&(hash[0]), libgit2_d.indexer.git_indexer_hash(idx));
		core.stdc.stdio.puts(&(hash[0]));

		return error;
	}
