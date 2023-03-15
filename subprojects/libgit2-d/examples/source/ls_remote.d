module libgit2_d.example.ls_remote;


private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import libgit2_d.example.common;
private static import libgit2_d.net;
private static import libgit2_d.oid;
private static import libgit2_d.remote;
private static import libgit2_d.types;

package:

nothrow @nogc
private int use_remote(libgit2_d.types.git_repository* repo, char* name)

	in
	{
	}

	do
	{
		libgit2_d.remote.git_remote_callbacks callbacks = libgit2_d.remote.GIT_REMOTE_CALLBACKS_INIT();

		/* Find the remote by name */
		libgit2_d.types.git_remote* remote = null;

		scope (exit) {
			libgit2_d.remote.git_remote_free(remote);
		}

		int error = libgit2_d.remote.git_remote_lookup(&remote, repo, name);

		if (error < 0) {
			error = libgit2_d.remote.git_remote_create_anonymous(&remote, repo, name);

			if (error < 0) {
				return error;
			}
		}

		/**
		 * Connect to the remote and call the printing function for
		 * each of the remote references.
		 */
		callbacks.credentials = &libgit2_d.example.common.cred_acquire_cb;

		error = libgit2_d.remote.git_remote_connect(remote, libgit2_d.net.git_direction.GIT_DIRECTION_FETCH, &callbacks, null, null);

		if (error < 0) {
			return error;
		}

		/**
		 * Get the list of references on the remote and print out
		 * their name next to what they point to.
		 */
		size_t refs_len;

		const (libgit2_d.net.git_remote_head)** refs;

		if (libgit2_d.remote.git_remote_ls(&refs, &refs_len, remote) < 0) {
			return error;
		}

		for (size_t i = 0; i < refs_len; i++) {
			char[libgit2_d.oid.GIT_OID_HEXSZ + 1] oid  = '\0';
			libgit2_d.oid.git_oid_fmt((&oid[0]), &refs[i].oid);
			core.stdc.stdio.printf("%s\t%s\n", (&oid[0]), refs[i].name);
		}

		return error;
	}

/**
 * Entry point for this command
 */
extern (C)
nothrow @nogc
public int lg2_ls_remote(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		if (argc < 2) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "usage: %s ls-remote <remote>\n", argv[-1]);

			return core.stdc.stdlib.EXIT_FAILURE;
		}

		int error = .use_remote(repo, argv[1]);

		return error;
	}
