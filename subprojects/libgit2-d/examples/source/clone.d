module libgit2_d.example.clone;


private static import core.stdc.stdio;
private static import libgit2_d.checkout;
private static import libgit2_d.clone;
private static import libgit2_d.errors;
private static import libgit2_d.example.common;
private static import libgit2_d.indexer;
private static import libgit2_d.repository;
private static import libgit2_d.types;

package:

public struct progress_data
{
	libgit2_d.indexer.git_indexer_progress fetch_progress;
	size_t completed_steps;
	size_t total_steps;
	const (char)* path;
}

extern (C)
nothrow @nogc
private void print_progress(const (.progress_data)* pd)

	in
	{
	}

	do
	{
		int network_percent = (pd.fetch_progress.total_objects > 0) ? ((100 * pd.fetch_progress.received_objects) / pd.fetch_progress.total_objects) : (0);
		int index_percent = (pd.fetch_progress.total_objects > 0) ? ((100 * pd.fetch_progress.indexed_objects) / pd.fetch_progress.total_objects) : (0);

		int checkout_percent = (pd.total_steps > 0) ? (cast(int)((100 * pd.completed_steps) / pd.total_steps)) : (0);
		size_t kbytes = pd.fetch_progress.received_bytes / 1024;

		if ((pd.fetch_progress.total_objects) && (pd.fetch_progress.received_objects == pd.fetch_progress.total_objects)) {
			core.stdc.stdio.printf("Resolving deltas %u/%u\r", pd.fetch_progress.indexed_deltas, pd.fetch_progress.total_deltas);
		} else {
			core.stdc.stdio.printf("net %3d%% (%4" ~ libgit2_d.example.common.PRIuZ ~ " kb, %5u/%5u)  /  idx %3d%% (%5u/%5u)  /  chk %3d%% (%4" ~ libgit2_d.example.common.PRIuZ ~ "/%4" ~ libgit2_d.example.common.PRIuZ ~ ")%s\n", network_percent, kbytes, pd.fetch_progress.received_objects, pd.fetch_progress.total_objects, index_percent, pd.fetch_progress.indexed_objects, pd.fetch_progress.total_objects, checkout_percent, pd.completed_steps, pd.total_steps, pd.path);
		}
	}

extern (C)
nothrow @nogc
private int sideband_progress(const (char)* str, int len, void* payload)

	in
	{
	}

	do
	{
		//cast(void)(payload);

		core.stdc.stdio.printf("remote: %.*s", len, str);
		core.stdc.stdio.fflush(core.stdc.stdio.stdout);

		return 0;
	}

extern (C)
nothrow @nogc
private int fetch_progress(const (libgit2_d.indexer.git_indexer_progress)* stats, void* payload)

	in
	{
	}

	do
	{
		.progress_data* pd = cast(.progress_data*)(payload);
		pd.fetch_progress = *stats;
		.print_progress(pd);

		return 0;
	}

extern (C)
nothrow @nogc
private void checkout_progress(const (char)* path, size_t cur, size_t tot, void* payload)

	in
	{
	}

	do
	{
		.progress_data* pd = cast(.progress_data*)(payload);
		pd.completed_steps = cur;
		pd.total_steps = tot;
		pd.path = path;
		.print_progress(pd);
	}

extern (C)
nothrow @nogc
public int lg2_clone(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		//cast(void)(repo);
		const (char)* url = argv[1];
		const (char)* path = argv[2];

		/* Validate args */
		if (argc < 3) {
			core.stdc.stdio.printf("USAGE: %s <url> <path>\n", argv[0]);

			return -1;
		}

		/* Set up options */
		.progress_data pd = .progress_data.init;
		libgit2_d.checkout.git_checkout_options checkout_opts = libgit2_d.checkout.GIT_CHECKOUT_OPTIONS_INIT();
		checkout_opts.checkout_strategy = libgit2_d.checkout.git_checkout_strategy_t.GIT_CHECKOUT_SAFE;
		checkout_opts.progress_cb = &.checkout_progress;
		checkout_opts.progress_payload = &pd;
		libgit2_d.clone.git_clone_options clone_opts = libgit2_d.clone.GIT_CLONE_OPTIONS_INIT();
		clone_opts.checkout_opts = checkout_opts;
		clone_opts.fetch_opts.callbacks.sideband_progress = &.sideband_progress;
		clone_opts.fetch_opts.callbacks.transfer_progress = &.fetch_progress;
		clone_opts.fetch_opts.callbacks.credentials = &libgit2_d.example.common.cred_acquire_cb;
		clone_opts.fetch_opts.callbacks.payload = &pd;

		/* Do the clone */
		libgit2_d.types.git_repository* cloned_repo = null;
		int error = libgit2_d.clone.git_clone(&cloned_repo, url, path, &clone_opts);
		core.stdc.stdio.printf("\n");

		if (error != 0) {
			const (libgit2_d.errors.git_error)* err = libgit2_d.errors.git_error_last();

			if (err != null) {
				core.stdc.stdio.printf("ERROR %d: %s\n", err.klass, err.message);
			} else {
				core.stdc.stdio.printf("ERROR %d: no detailed info\n", error);
			}
		} else if (cloned_repo != null) {
			libgit2_d.repository.git_repository_free(cloned_repo);
		}

		return error;
	}
