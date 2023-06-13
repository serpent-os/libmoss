module libgit2_d.example.fetch;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import libgit2_d.example.common;
private static import libgit2_d.indexer;
private static import libgit2_d.oid;
private static import libgit2_d.remote;
private static import libgit2_d.types;

package:

extern (C)
nothrow @nogc
private int progress_cb(const (char)* str, int len, void* data)

	in
	{
	}

	do
	{
		//cast(void)(data);
		core.stdc.stdio.printf("remote: %.*s", len, str);

		/* We don't have the \n to force the flush */
		core.stdc.stdio.fflush(core.stdc.stdio.stdout);

		return 0;
	}

/**
 * This function gets called for each remote-tracking branch that gets
 * updated. The message we output depends on whether it's a new one or
 * an update.
 */
extern (C)
nothrow @nogc
private int update_cb(const (char)* refname, const (libgit2_d.oid.git_oid)* a, const (libgit2_d.oid.git_oid)* b, void* data)

	in
	{
	}

	do
	{
		//cast(void)(data);

		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] b_str;
		libgit2_d.oid.git_oid_fmt(&(b_str[0]), b);
		b_str[libgit2_d.oid.GIT_OID_HEXSZ] = '\0';

		if (libgit2_d.oid.git_oid_is_zero(a)) {
			core.stdc.stdio.printf("[new]     %.20s %s\n", &(b_str[0]), refname);
		} else {
			char[libgit2_d.oid.GIT_OID_HEXSZ + 1] a_str;
			libgit2_d.oid.git_oid_fmt(&(a_str[0]), a);
			a_str[libgit2_d.oid.GIT_OID_HEXSZ] = '\0';
			core.stdc.stdio.printf("[updated] %.10s..%.10s %s\n", &(a_str[0]), &(b_str[0]), refname);
		}

		return 0;
	}

/**
 * This gets called during the download and indexing. Here we show
 * processed and total objects in the pack and the amount of received
 * data. Most frontends will probably want to show a percentage and
 * the download rate.
 */
extern (C)
nothrow @nogc
private int transfer_progress_cb(const (libgit2_d.indexer.git_indexer_progress)* stats, void* payload)

	in
	{
	}

	do
	{
		//cast(void)(payload);

		if (stats.received_objects == stats.total_objects) {
			core.stdc.stdio.printf("Resolving deltas %u/%u\r", stats.indexed_deltas, stats.total_deltas);
		} else if (stats.total_objects > 0) {
			core.stdc.stdio.printf("Received %u/%u objects (%u) in %" ~ libgit2_d.example.common.PRIuZ ~ " bytes\r", stats.received_objects, stats.total_objects, stats.indexed_objects, stats.received_bytes);
		}

		return 0;
	}

/**
 * Entry point for this command
 */
extern (C)
nothrow @nogc
public int lg2_fetch(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		if (argc < 2) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: %s fetch <repo>\n", argv[-1]);

			return core.stdc.stdlib.EXIT_FAILURE;
		}

		/* Figure out whether it's a named remote or a URL */
		core.stdc.stdio.printf("Fetching %s for repo %p\n", argv[1], repo);

		libgit2_d.types.git_remote* remote = null;

		scope (exit) {
			libgit2_d.remote.git_remote_free(remote);
		}

		if (libgit2_d.remote.git_remote_lookup(&remote, repo, argv[1]) < 0) {
			if (libgit2_d.remote.git_remote_create_anonymous(&remote, repo, argv[1]) < 0) {
				return -1;
			}
		}

		/* Set up the callbacks (only update_tips for now) */
		libgit2_d.remote.git_fetch_options fetch_opts = libgit2_d.remote.GIT_FETCH_OPTIONS_INIT();
		fetch_opts.callbacks.update_tips = &.update_cb;
		fetch_opts.callbacks.sideband_progress = &.progress_cb;
		fetch_opts.callbacks.transfer_progress = &.transfer_progress_cb;
		fetch_opts.callbacks.credentials = &libgit2_d.example.common.cred_acquire_cb;

		/**
		 * Perform the fetch with the configured refspecs from the
		 * config. Update the reflog for the updated references with
		 * "fetch".
		 */
		if (libgit2_d.remote.git_remote_fetch(remote, null, &fetch_opts, "fetch") < 0) {
			return -1;
		}

		/**
		 * If there are local objects (we got a thin pack), then tell
		 * the user how many objects we saved from having to cross the
		 * network.
		 */
		const (libgit2_d.indexer.git_indexer_progress)* stats = libgit2_d.remote.git_remote_stats(remote);

		if (stats.local_objects > 0) {
			core.stdc.stdio.printf("\rReceived %u/%u objects in %" ~ libgit2_d.example.common.PRIuZ ~ " bytes (used %u local objects)\n", stats.indexed_objects, stats.total_objects, stats.received_bytes, stats.local_objects);
		} else {
			core.stdc.stdio.printf("\rReceived %u/%u objects in %" ~ libgit2_d.example.common.PRIuZ ~ "bytes\n", stats.indexed_objects, stats.total_objects, stats.received_bytes);
		}

		libgit2_d.remote.git_remote_free(remote);

		return 0;
	}
