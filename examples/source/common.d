/*
 * Utilities library for libgit2 examples
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
module libgit2_d.example.common;


private static import core.stdc.errno;
private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import core.sys.posix.fcntl;
private static import core.sys.posix.stdio;
private static import core.sys.posix.strings;
private static import core.sys.posix.sys.stat;
private static import core.sys.posix.sys.types;
private static import core.sys.posix.unistd;
private static import core.sys.windows.stat;
private static import core.sys.windows.winbase;
private static import libgit2_d.annotated_commit;
private static import libgit2_d.credential;
private static import libgit2_d.diff;
private static import libgit2_d.errors;
private static import libgit2_d.object;
private static import libgit2_d.refs;
private static import libgit2_d.revparse;
private static import libgit2_d.types;

package:

version (Windows) {
	alias open = core.stdc.stdio._open;

	extern
	extern (C)
	nothrow @nogc @system
	int _read(int, void*, uint);

	alias read = _read;
	alias close = core.stdc.stdio._close;
	alias ssize_t = int;

	pragma(inline, true)
	nothrow @nogc
	void sleep(int a)

		do
		{
			core.sys.windows.winbase.Sleep(a * 1000);
		}

	alias O_RDONLY = core.stdc.stdio.O_RDONLY;
	alias stat = core.sys.windows.stat.struct_stat;
	alias fstat = core.sys.windows.stat.fstat;
} else {
	//package static import core.sys.posix.unistd;

	alias open = core.sys.posix.fcntl.open;
	alias read = core.sys.posix.unistd.read;
	alias close = core.sys.posix.unistd.close;
	alias ssize_t = core.sys.posix.sys.types.ssize_t;
	alias sleep = core.sys.posix.unistd.sleep;
	alias O_RDONLY = core.sys.posix.fcntl.O_RDONLY;
	alias stat = core.sys.posix.sys.stat.stat_t;
	alias fstat = core.sys.posix.sys.stat.fstat;
}

/* Define the printf format specifer to use for size_t output */
//#if defined(_MSC_VER) || defined(__MINGW32__)
version (Windows) {
	enum PRIuZ = "Iu";
} else {
	enum PRIuZ = "zu";
}

version (Windows) {
	alias snprintf = core.stdc.stdio.snprintf;
	//alias strcasecmp = strcmpi;
} else {
	alias snprintf = core.sys.posix.stdio.snprintf;
	alias strcasecmp = core.sys.posix.strings.strcasecmp;
}

/**
 * Check libgit2 error code, printing error to stderr on failure and
 * exiting the program.
 */
nothrow @nogc
public void check_lg2(int error, const (char)* message, const (char)* extra)

	in
	{
	}

	do
	{
		if (!error) {
			return;
		}

		const (libgit2_d.errors.git_error)* lg2err = libgit2_d.errors.git_error_last();
		const (char)* lg2msg = "";
		const (char)* lg2spacer = "";

		if ((lg2err != null) && (lg2err.message != null)) {
			lg2msg = lg2err.message;
			lg2spacer = " - ";
		}

		if (extra != null) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "%s '%s' [%d]%s%s\n", message, extra, error, lg2spacer, lg2msg);
		} else {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "%s [%d]%s%s\n", message, error, lg2spacer, lg2msg);
		}

		core.stdc.stdlib.exit(1);
	}

/**
 * Exit the program, printing error to stderr
 */
nothrow @nogc
public void fatal(const (char)* message, const (char)* extra)

	in
	{
	}

	do
	{
		if (extra != null) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "%s %s\n", message, extra);
		} else {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "%s\n", message);
		}

		core.stdc.stdlib.exit(1);
	}

/**
 * Basic output function for plain text diff output
 * Pass `core.stdc.stdio.FILE*` such as `core.stdc.stdio.stdout` or `core.stdc.stdio.stderr` as payload (or null == `core.stdc.stdio.stdout`)
 */
extern (C)
nothrow @nogc
public int diff_output(const (libgit2_d.diff.git_diff_delta)* d, const (libgit2_d.diff.git_diff_hunk)* h, const (libgit2_d.diff.git_diff_line)* l, void* p)

	in
	{
	}

	do
	{
		core.stdc.stdio.FILE* fp = cast(core.stdc.stdio.FILE*)(p);

		//cast(void)(d);
		//cast(void)(h);

		if (fp == null) {
			fp = core.stdc.stdio.stdout;
		}

		if ((l.origin == libgit2_d.diff.git_diff_line_t.GIT_DIFF_LINE_CONTEXT) || (l.origin == libgit2_d.diff.git_diff_line_t.GIT_DIFF_LINE_ADDITION) || (l.origin == libgit2_d.diff.git_diff_line_t.GIT_DIFF_LINE_DELETION)) {
			core.stdc.stdio.fputc(l.origin, fp);
		}

		core.stdc.stdio.fwrite(l.content, 1, l.content_len, fp);

		return 0;
	}

/**
 * Convert a treeish argument to an actual tree; this will call check_lg2
 * and exit the program if `treeish` cannot be resolved to a tree
 */
nothrow @nogc
public void treeish_to_tree(libgit2_d.types.git_tree** out_, libgit2_d.types.git_repository* repo, const (char)* treeish)

	in
	{
	}

	do
	{
		libgit2_d.types.git_object* obj = null;

		.check_lg2(libgit2_d.revparse.git_revparse_single(&obj, repo, treeish), "looking up object", treeish);

		.check_lg2(libgit2_d.object.git_object_peel(cast(libgit2_d.types.git_object**)(out_), obj, libgit2_d.types.git_object_t.GIT_OBJECT_TREE), "resolving object to tree", treeish);

		libgit2_d.object.git_object_free(obj);
	}

/**
 * A realloc that exits on failure
 */
nothrow @nogc
public void* xrealloc(void* oldp, size_t newsz)

	in
	{
	}

	do
	{
		void* p = core.stdc.stdlib.realloc(oldp, newsz);

		if (p == null) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "Cannot allocate memory, exiting.\n");
			core.stdc.stdlib.exit(1);
		}

		return p;
	}

/**
 * Convert a refish to an annotated commit.
 */
nothrow @nogc
public int resolve_refish(libgit2_d.types.git_annotated_commit** commit, libgit2_d.types.git_repository* repo, const (char)* refish)

	in
	{
		assert(commit != null);
	}

	do
	{
		libgit2_d.types.git_reference* ref_;
		int err = libgit2_d.refs.git_reference_dwim(&ref_, repo, refish);

		if (err == libgit2_d.errors.git_error_code.GIT_OK) {
			libgit2_d.annotated_commit.git_annotated_commit_from_ref(commit, repo, ref_);
			libgit2_d.refs.git_reference_free(ref_);

			return 0;
		}

		libgit2_d.types.git_object* obj;
		err = libgit2_d.revparse.git_revparse_single(&obj, repo, refish);

		if (err == libgit2_d.errors.git_error_code.GIT_OK) {
			err = libgit2_d.annotated_commit.git_annotated_commit_lookup(commit, repo, libgit2_d.object.git_object_id(obj));
			libgit2_d.object.git_object_free(obj);
		}

		return err;
	}

nothrow @nogc
private int readline(char** out_)

	in
	{
	}

	do
	{
		int c;
		int error = 0;
		int length = 0;
		int allocated = 0;
		char* line = null;

		scope (exit) {
			if (line != null) {
				core.stdc.stdlib.free(line);
				line = null;
			}
		}

		core.stdc.errno.errno = 0;

		while ((c = core.stdc.stdio.getchar()) != core.stdc.stdio.EOF) {
			if (length == allocated) {
				allocated += 16;
				line = cast(char*)(core.stdc.stdlib.realloc(line, allocated));

				if (line == null) {
					error = -1;

					return error;
				}
			}

			if (c == '\n') {
				break;
			}

			line[length++] = cast(char)(c);
		}

		if (core.stdc.errno.errno != 0) {
			error = -1;

			return error;
		}

		line[length] = '\0';
		*out_ = line;
		line = null;
		error = length;

		return error;
	}

nothrow @nogc
private int ask(char** out_, const (char)* prompt, char optional)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("%s ", prompt);
		core.stdc.stdio.fflush(core.stdc.stdio.stdout);

		if ((!.readline(out_)) && (!optional)) {
			core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "Could not read response: %s", core.stdc.string.strerror(core.stdc.errno.errno));

			return -1;
		}

		return 0;
	}

/**
 * Acquire credentials via command line
 */
extern (C)
nothrow @nogc
public int cred_acquire_cb(libgit2_d.credential.git_credential** out_, const (char)* url, const (char)* username_from_url, uint allowed_types, void* payload)

	in
	{
	}

	do
	{
		char* username = null;
		char* password = null;
		char* privkey = null;
		char* pubkey = null;
		int error = 1;

		//cast(void)(url);
		//cast(void)(payload);

		scope (exit) {
			if (username != null) {
				core.stdc.stdlib.free(username);
				username = null;
			}

			if (password != null) {
				core.stdc.stdlib.free(password);
				password = null;
			}

			if (privkey != null) {
				core.stdc.stdlib.free(privkey);
				privkey = null;
			}

			if (pubkey != null) {
				core.stdc.stdlib.free(pubkey);
				pubkey = null;
			}
		}

		if (username_from_url != null) {
			username = core.stdc.string.strdup(username_from_url);

			if (username == null) {
				return error;
			}
		} else {
			error = .ask(&username, "Username:", 0);

			if (error < 0) {
				return error;
			}
		}

		if (allowed_types & libgit2_d.credential.git_credential_t.GIT_CREDENTIAL_SSH_KEY) {
			int n;

			error = .ask(&privkey, "SSH Key:", 0);

			if (error < 0) {
				return error;
			}

			error = .ask(&password, "Password:", 1);

			if (error < 0) {
				return error;
			}

			n = .snprintf(null, 0, "%s.pub", privkey);

			if (n < 0) {
				return error;
			}

			pubkey = cast(char*)(core.stdc.stdlib.malloc(n + 1));

			if (pubkey == null) {
				return error;
			}

			n = .snprintf(pubkey, n + 1, "%s.pub", privkey);

			if (n < 0) {
				return error;
			}

			error = libgit2_d.credential.git_credential_ssh_key_new(out_, username, pubkey, privkey, password);
		} else if (allowed_types & libgit2_d.credential.git_credential_t.GIT_CREDENTIAL_USERPASS_PLAINTEXT) {
			error = .ask(&password, "Password:", 1);

			if (error < 0) {
				return error;
			}

			error = libgit2_d.credential.git_credential_userpass_plaintext_new(out_, username, password);
		} else if (allowed_types & libgit2_d.credential.git_credential_t.GIT_CREDENTIAL_USERNAME) {
			error = libgit2_d.credential.git_credential_username_new(out_, username);
		}

		return error;
	}

/**
 * Read a file into a buffer
 *
 * Params:
 *      path = The path to the file that shall be read
 *
 * Returns: NUL-terminated buffer if the file was successfully read, null-pointer otherwise
 */
nothrow @nogc
public char* read_file(const (char)* path)

	in
	{
	}

	do
	{
		int fd = .open(path, .O_RDONLY);

		if (fd < 0) {
			return null;
		}

		scope (exit) {
			if (fd >= 0) {
				.close(fd);
			}
		}

		.stat st;

		if (.fstat(fd, &st) < 0) {
			return null;
		}

		char* buf = cast(char*)(core.stdc.stdlib.malloc(st.st_size + 1));

		if (buf == null) {
			return buf;
		}

		.ssize_t total = 0;

		while (total < st.st_size) {
			.ssize_t bytes = .read(fd, buf + total, st.st_size - total);

			if (bytes <= 0) {
				if ((core.stdc.errno.errno == core.stdc.errno.EAGAIN) || (core.stdc.errno.errno == core.stdc.errno.EINTR)) {
					continue;
				}

				core.stdc.stdlib.free(buf);
				buf = null;

				return buf;
			}

			total += bytes;
		}

		buf[total] = '\0';

		return buf;
	}
