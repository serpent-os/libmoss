/*
 * libgit2 "general" example - shows basic libgit2 concepts
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

/**
 * [**libgit2**][lg] is a portable, pure C implementation of the Git core
 * methods provided as a re-entrant linkable library with a solid API,
 * allowing you to write native speed custom Git applications in any
 * language which supports C bindings.
 *
 * This file is an example of using that API in a real, compilable C file.
 * As the API is updated, this file will be updated to demonstrate the new
 * functionality.
 *
 * If you're trying to write something in C using [libgit2][lg], you should
 * also check out the generated [API documentation][ap]. We try to link to
 * the relevant sections of the API docs in each section in this file.
 *
 * **libgit2** (for the most part) only implements the core plumbing
 * functions, not really the higher level porcelain stuff. For a primer on
 * Git Internals that you will need to know to work with Git at this level,
 * check out [Chapter 10][pg] of the Pro Git book.
 *
 * [lg]: http://libgit2.github.com
 * [ap]: http://libgit2.github.com/libgit2
 * [pg]: https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain
 */
module libgit2_d.example.general;


private static import core.stdc.config;
private static import core.stdc.stdio;
private static import core.stdc.stdlib;
private static import core.stdc.time;
private static import libgit2_d.blob;
private static import libgit2_d.commit;
private static import libgit2_d.common;
private static import libgit2_d.config;
private static import libgit2_d.deprecated_;
private static import libgit2_d.errors;
private static import libgit2_d.global;
private static import libgit2_d.index;
private static import libgit2_d.object;
private static import libgit2_d.odb;
private static import libgit2_d.oid;
private static import libgit2_d.refs;
private static import libgit2_d.repository;
private static import libgit2_d.revwalk;
private static import libgit2_d.signature;
private static import libgit2_d.strarray;
private static import libgit2_d.tag;
private static import libgit2_d.tree;
private static import libgit2_d.types;

package:

/**
 * ### Includes
 *
 * Including the `git2.h` header will include all the other libgit2 headers
 * that you need.  It should be the only thing you need to include in order
 * to compile properly and get all the libgit2 API.
 */
//private void oid_parsing(libgit2_d.oid.git_oid* out_);
//private void object_database(libgit2_d.types.git_repository* repo, libgit2_d.oid.git_oid* oid);
//private void commit_writing(libgit2_d.types.git_repository* repo);
//private void commit_parsing(libgit2_d.types.git_repository* repo);
//private void tag_parsing(libgit2_d.types.git_repository* repo);
//private void tree_parsing(libgit2_d.types.git_repository* repo);
//private void blob_parsing(libgit2_d.types.git_repository* repo);
//private void revwalking(libgit2_d.types.git_repository* repo);
//private void index_walking(libgit2_d.types.git_repository* repo);
//private void reference_listing(libgit2_d.types.git_repository* repo);
//private void config_files(const (char)* repo_path, libgit2_d.types.git_repository* repo);

/**
 * Almost all libgit2 functions return 0 on success or negative on error.
 * This is not production quality error checking, but should be sufficient
 * as an example.
 */
nothrow @nogc
private void check_error(int error_code, const (char)* action)

	in
	{
	}

	do
	{
		const (libgit2_d.errors.git_error)* error = libgit2_d.errors.git_error_last();

		if (!error_code) {
			return;
		}

		core.stdc.stdio.printf("Error %d %s - %s\n", error_code, action, ((error) && (error.message)) ? (error.message) : ("???"));

		core.stdc.stdlib.exit(1);
	}

extern (C)
nothrow @nogc
public int lg2_general(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		/**
		 * Initialize the library, this will set up any global state which libgit2 needs
		 * including threading and crypto
		 */
		libgit2_d.global.git_libgit2_init();

		/**
		 * ### Opening the Repository
		 *
		 * There are a couple of methods for opening a repository, this being the
		 * simplest.  There are also [methods][me] for specifying the index file
		 * and work tree locations, here we assume they are in the normal places.
		 *
		 * (Try running this program against tests/resources/testrepo.git.)
		 *
		 * [me]: http://libgit2.github.com/libgit2/#HEAD/group/repository
		 */
		const char* repo_path = (argc > 1) ? (argv[1]) : ("/opt/libgit2-test/.git");

		int error = libgit2_d.repository.git_repository_open(&repo, repo_path);
		.check_error(error, "opening repository");

		libgit2_d.oid.git_oid oid;
		.oid_parsing(&oid);
		.object_database(repo, &oid);
		.commit_writing(repo);
		.commit_parsing(repo);
		.tag_parsing(repo);
		.tree_parsing(repo);
		.blob_parsing(repo);
		.revwalking(repo);
		.index_walking(repo);
		.reference_listing(repo);
		.config_files(repo_path, repo);

		/**
		 * Finally, when you're done with the repository, you can free it as well.
		 */
		libgit2_d.repository.git_repository_free(repo);

		return 0;
	}

/**
 * ### SHA-1 Value Conversions
 */
nothrow @nogc
private void oid_parsing(libgit2_d.oid.git_oid* oid)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("*Hex to Raw*\n");

		/**
		 * For our first example, we will convert a 40 character hex value to the
		 * 20 byte raw SHA1 value.
		 *
		 * The `libgit2_d.oid.git_oid` is the structure that keeps the SHA value. We will use
		 * this throughout the example for storing the value of the current SHA
		 * key we're working with.
		 */
		const char* hex = "4a202b346bb0fb0db7eff3cffeb3c70babbd2045";
		libgit2_d.oid.git_oid_fromstr(oid, hex);

		/*
		 * Once we've converted the string into the oid value, we can get the raw
		 * value of the SHA by accessing `oid.id`
		 *
		 * Next we will convert the 20 byte raw SHA1 value to a human readable 40
		 * char hex value.
		 */
		core.stdc.stdio.printf("\n*Raw to Hex*\n");
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] out_ = '\0';

		/**
		 * If you have a oid, you can easily get the hex value of the SHA as well.
		 */
		libgit2_d.oid.git_oid_fmt(&(out_[0]), oid);

		/**
		 * If you have a oid, you can easily get the hex value of the SHA as well.
		 */
		libgit2_d.oid.git_oid_fmt(&(out_[0]), oid);
		core.stdc.stdio.printf("SHA hex string: %s\n", &(out_[0]));
	}

/**
 * ### Working with the Object Database
 *
 * **libgit2** provides [direct access][odb] to the object database.  The
 * object database is where the actual objects are stored in Git. For
 * working with raw objects, we'll need to get this structure from the
 * repository.
 *
 * [odb]: http://libgit2.github.com/libgit2/#HEAD/group/odb
 */
nothrow @nogc
private void object_database(libgit2_d.types.git_repository* repo, libgit2_d.oid.git_oid* oid)

	in
	{
	}

	do
	{
		libgit2_d.types.git_odb* odb;
		libgit2_d.repository.git_repository_odb(&odb, repo);

		/**
		 * #### Raw Object Reading
		 */

		core.stdc.stdio.printf("\n*Raw Object Read*\n");

		/**
		 * We can read raw objects directly from the object database if we have
		 * the oid (SHA) of the object.  This allows us to access objects without
		 * knowing their type and inspect the raw bytes unparsed.
		 */
		libgit2_d.types.git_odb_object* obj;
		int error = libgit2_d.odb.git_odb_read(&obj, odb, oid);
		.check_error(error, "finding object in repository");

		/**
		 * A raw object only has three properties - the type (commit, blob, tree
		 * or tag), the size of the raw data and the raw, unparsed data itself.
		 * For a commit or tag, that raw data is human readable plain ASCII
		 * text. For a blob it is just file contents, so it could be text or
		 * binary data. For a tree it is a special binary format, so it's unlikely
		 * to be hugely helpful as a raw object.
		 */
		const (ubyte)* data = cast(const (ubyte)*)(libgit2_d.odb.git_odb_object_data(obj));
		libgit2_d.types.git_object_t otype = libgit2_d.odb.git_odb_object_type(obj);

		/**
		 * We provide methods to convert from the object type which is an enum, to
		 * a string representation of that value (and vice-versa).
		 */
		const (char)* str_type = libgit2_d.object.git_object_type2string(otype);
		core.stdc.stdio.printf("object length and type: %d, %s\nobject data: %s\n", cast(int)(libgit2_d.odb.git_odb_object_size(obj)), str_type, data);

		/**
		 * For proper memory management, close the object when you are done with
		 * it or it will leak memory.
		 */
		libgit2_d.odb.git_odb_object_free(obj);

		/**
		 * #### Raw Object Writing
		 */

		core.stdc.stdio.printf("\n*Raw Object Write*\n");

		/**
		 * You can also write raw object data to Git. This is pretty cool because
		 * it gives you direct access to the key/value properties of Git.  Here
		 * we'll write a new blob object that just contains a simple string.
		 * Notice that we have to specify the object type as the `libgit2_d.deprecated_.git_object_t` enum.
		 */
		enum test_data = "test data";
		libgit2_d.odb.git_odb_write(oid, odb, test_data.ptr, test_data.length, libgit2_d.types.git_object_t.GIT_OBJECT_BLOB);

		/**
		 * Now that we've written the object, we can check out what SHA1 was
		 * generated when the object was written to our database.
		 */
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] oid_hex  = '\0';
		libgit2_d.oid.git_oid_fmt(&(oid_hex[0]), oid);
		core.stdc.stdio.printf("Written Object: %s\n", &(oid_hex[0]));

		/**
		 * Free the object database after usage.
		 */
		libgit2_d.odb.git_odb_free(odb);
	}

/**
 * #### Writing Commits
 *
 * libgit2 provides a couple of methods to create commit objects easily as
 * well. There are four different create signatures, we'll just show one
 * of them here.  You can read about the other ones in the [commit API
 * docs][cd].
 *
 * [cd]: http://libgit2.github.com/libgit2/#HEAD/group/commit
 */
nothrow @nogc
private void commit_writing(libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("\n*Commit Writing*\n");

		/**
		 * Creating signatures for an authoring identity and time is simple.  You
		 * will need to do this to specify who created a commit and when.  Default
		 * values for the name and email should be found in the `user.name` and
		 * `user.email` configuration options.  See the `config` section of this
		 * example file to see how to access config values.
		 */
		libgit2_d.types.git_signature* author;
		libgit2_d.signature.git_signature_new(&author, "Scott Chacon", "schacon@gmail.com", 123456789, 60);
		libgit2_d.types.git_signature* committer;
		libgit2_d.signature.git_signature_new(&committer, "Scott A Chacon", "scott@github.com", 987654321, 90);

		/**
		 * Commit objects need a tree to point to and optionally one or more
		 * parents.  Here we're creating oid objects to create the commit with,
		 * but you can also use
		 */
		libgit2_d.oid.git_oid tree_id;
		libgit2_d.oid.git_oid_fromstr(&tree_id, "f60079018b664e4e79329a7ef9559c8d9e0378d1");
		libgit2_d.types.git_tree* tree;
		libgit2_d.tree.git_tree_lookup(&tree, repo, &tree_id);
		libgit2_d.oid.git_oid parent_id;
		libgit2_d.oid.git_oid_fromstr(&parent_id, "5b5b025afb0b4c913b4c338a42934a3863bf3644");
		libgit2_d.types.git_commit* parent;
		libgit2_d.commit.git_commit_lookup(&parent, repo, &parent_id);

		/**
		 * Here we actually create the commit object with a single call with all
		 * the values we need to create the commit.  The SHA key is written to the
		 * `commit_id` variable here.
		 */
		libgit2_d.oid.git_oid commit_id;
		libgit2_d.commit.git_commit_create_v(&commit_id, /* out id */
			repo, null, /* do not update the HEAD */
			author, committer, null, /* use default message encoding */
			"example commit", tree, 1, parent);

		/**
		 * Now we can take a look at the commit SHA we've generated.
		 */
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] oid_hex  = '\0';
		libgit2_d.oid.git_oid_fmt(&(oid_hex[0]), &commit_id);
		core.stdc.stdio.printf("New Commit: %s\n", &(oid_hex[0]));

		/**
		 * Free all objects used in the meanwhile.
		 */
		libgit2_d.tree.git_tree_free(tree);
		libgit2_d.commit.git_commit_free(parent);
		libgit2_d.signature.git_signature_free(author);
		libgit2_d.signature.git_signature_free(committer);
	}

/**
 * ### Object Parsing
 *
 * libgit2 has methods to parse every object type in Git so you don't have
 * to work directly with the raw data. This is much faster and simpler
 * than trying to deal with the raw data yourself.
 */

/**
 * #### Commit Parsing
 *
 * [Parsing commit objects][pco] is simple and gives you access to all the
 * data in the commit - the author (name, email, datetime), committer
 * (same), tree, message, encoding and parent(s).
 *
 * [pco]: http://libgit2.github.com/libgit2/#HEAD/group/commit
 */
nothrow @nogc
private void commit_parsing(libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("\n*Commit Parsing*\n");

		libgit2_d.oid.git_oid oid;
		libgit2_d.oid.git_oid_fromstr(&oid, "8496071c1b46c854b31185ea97743be6a8774479");

		libgit2_d.types.git_commit* commit;
		int error = libgit2_d.commit.git_commit_lookup(&commit, repo, &oid);
		.check_error(error, "looking up commit");

		/**
		 * Each of the properties of the commit object are accessible via methods,
		 * including commonly needed variations, such as `libgit2_d.commit.git_commit_time` which
		 * returns the author time and `libgit2_d.commit.git_commit_message` which gives you the
		 * commit message (as a NUL-terminated string).
		 */
		const (char)* message = libgit2_d.commit.git_commit_message(commit);
		const (libgit2_d.types.git_signature)* author = libgit2_d.commit.git_commit_author(commit);
		const (libgit2_d.types.git_signature)* cmtter = libgit2_d.commit.git_commit_committer(commit);

		//ToDo:
		//core.stdc.time.time_t time = libgit2_d.commit.git_commit_time(commit);
		core.stdc.time.time_t time = cast(core.stdc.time.time_t)(libgit2_d.commit.git_commit_time(commit));

		/**
		 * The author and committer methods return [libgit2_d.types.git_signature] structures,
		 * which give you name, email and `when`, which is a `libgit2_d.types.git_time` structure,
		 * giving you a timestamp and timezone offset.
		 */
		core.stdc.stdio.printf("Author: %s (%s)\nCommitter: %s (%s)\nDate: %s\nMessage: %s\n", author.name, author.email, cmtter.name, cmtter.email, core.stdc.time.ctime(&time), message);

		/**
		 * Commits can have zero or more parents. The first (root) commit will
		 * have no parents, most commits will have one (i.e. the commit it was
		 * based on) and merge commits will have two or more.  Commits can
		 * technically have any number, though it's rare to have more than two.
		 */
		uint parents = libgit2_d.commit.git_commit_parentcount(commit);

		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] oid_hex;
		libgit2_d.types.git_commit* parent;

		for (uint p = 0; p < parents; p++) {
			oid_hex[] = 0;

			libgit2_d.commit.git_commit_parent(&parent, commit, p);
			libgit2_d.oid.git_oid_fmt(&(oid_hex[0]), libgit2_d.commit.git_commit_id(parent));
			core.stdc.stdio.printf("Parent: %s\n", &(oid_hex[0]));
			libgit2_d.commit.git_commit_free(parent);
		}

		libgit2_d.commit.git_commit_free(commit);
	}

/**
 * #### Tag Parsing
 *
 * You can parse and create tags with the [tag management API][core.stdc.time.tm], which
 * functions very similarly to the commit lookup, parsing and creation
 * methods, since the objects themselves are very similar.
 *
 * [core.stdc.time.tm]: http://libgit2.github.com/libgit2/#HEAD/group/tag
 */
nothrow @nogc
private void tag_parsing(libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("\n*Tag Parsing*\n");

		/**
		 * We create an oid for the tag object if we know the SHA and look it up
		 * the same way that we would a commit (or any other object).
		 */
		libgit2_d.oid.git_oid oid;
		libgit2_d.oid.git_oid_fromstr(&oid, "b25fa35b38051e4ae45d4222e795f9df2e43f1d1");

		libgit2_d.types.git_tag* tag;
		int error = libgit2_d.tag.git_tag_lookup(&tag, repo, &oid);
		.check_error(error, "looking up tag");

		/**
		 * Now that we have the tag object, we can extract the information it
		 * generally contains: the target (usually a commit object), the type of
		 * the target object (usually 'commit'), the name ('v1.0'), the tagger (a
		 * git_signature - name, email, timestamp), and the tag message.
		 */
		libgit2_d.types.git_commit* commit;
		libgit2_d.tag.git_tag_target(cast(libgit2_d.types.git_object**)(&commit), tag);

		/* "test" */
		const (char)* name = libgit2_d.tag.git_tag_name(tag);

		/* libgit2_d.types.git_object_t.GIT_OBJECT_COMMIT (object_t enum) */
		libgit2_d.types.git_object_t type = libgit2_d.tag.git_tag_target_type(tag);

		/* "tag message\n" */
		const (char)* message = libgit2_d.tag.git_tag_message(tag);

		core.stdc.stdio.printf("Tag Name: %s\nTag Type: %s\nTag Message: %s\n", name, libgit2_d.object.git_object_type2string(type), message);

		/**
		 * Free both the commit and tag after usage.
		 */
		libgit2_d.commit.git_commit_free(commit);
		libgit2_d.tag.git_tag_free(tag);
	}

/**
 * #### Tree Parsing
 *
 * [Tree parsing][tp] is a bit different than the other objects, in that
 * we have a subtype which is the tree entry.  This is not an actual
 * object type in Git, but a useful structure for parsing and traversing
 * tree entries.
 *
 * [tp]: http://libgit2.github.com/libgit2/#HEAD/group/tree
 */
nothrow @nogc
private void tree_parsing(libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("\n*Tree Parsing*\n");

		/**
		 * Create the oid and lookup the tree object just like the other objects.
		 */
		libgit2_d.oid.git_oid oid;
		libgit2_d.oid.git_oid_fromstr(&oid, "f60079018b664e4e79329a7ef9559c8d9e0378d1");
		libgit2_d.types.git_tree* tree;
		libgit2_d.tree.git_tree_lookup(&tree, repo, &oid);

		/**
		 * Getting the count of entries in the tree so you can iterate over them
		 * if you want to.
		 */
		/* 2 */
		size_t cnt = libgit2_d.tree.git_tree_entrycount(tree);

		core.stdc.stdio.printf("tree entries: %d\n", cast(int)(cnt));

		const (libgit2_d.types.git_tree_entry)* entry = libgit2_d.tree.git_tree_entry_byindex(tree, 0);

		/* "README" */
		core.stdc.stdio.printf("Entry name: %s\n", libgit2_d.tree.git_tree_entry_name(entry));

		/**
		 * You can also access tree entries by name if you know the name of the
		 * entry you're looking for.
		 */
		entry = libgit2_d.tree.git_tree_entry_byname(tree, "README");

		/* "README" */
		libgit2_d.tree.git_tree_entry_name(entry);

		/**
		 * Once you have the entry object, you can access the content or subtree
		 * (or commit, in the case of submodules) that it points to.  You can also
		 * get the mode if you want.
		 */
		libgit2_d.types.git_object* obj;

		/* blob */
		libgit2_d.tree.git_tree_entry_to_object(&obj, repo, entry);

		/**
		 * Remember to close the looked-up object and tree once you are done using it
		 */
		libgit2_d.object.git_object_free(obj);
		libgit2_d.tree.git_tree_free(tree);
	}

/**
 * #### Blob Parsing
 *
 * The last object type is the simplest and requires the least parsing
 * help. Blobs are just file contents and can contain anything, there is
 * no structure to it. The main advantage to using the [simple blob
 * api][ba] is that when you're creating blobs you don't have to calculate
 * the size of the content.  There is also a helper for reading a file
 * from disk and writing it to the db and getting the oid back so you
 * don't have to do all those steps yourself.
 *
 * [ba]: http://libgit2.github.com/libgit2/#HEAD/group/blob
 */
nothrow @nogc
private void blob_parsing(libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("\n*Blob Parsing*\n");

		libgit2_d.oid.git_oid oid;
		libgit2_d.oid.git_oid_fromstr(&oid, "1385f264afb75a56a5bec74243be9b367ba4ca08");
		libgit2_d.types.git_blob* blob;
		libgit2_d.blob.git_blob_lookup(&blob, repo, &oid);

		/**
		 * You can access a buffer with the raw contents of the blob directly.
		 * Note that this buffer may not be contain ASCII data for certain blobs
		 * (e.g. binary files): do not consider the buffer a null-terminated
		 * string, and use the `libgit2_d.blob.git_blob_rawsize` attribute to find out its exact
		 * size in bytes
		 */
		/* 8 */
		core.stdc.stdio.printf("Blob Size: %ld\n", cast(core.stdc.config.c_long)(libgit2_d.blob.git_blob_rawsize(blob)));

		/* "content" */
		libgit2_d.blob.git_blob_rawcontent(blob);

		/**
		 * Free the blob after usage.
		 */
		libgit2_d.blob.git_blob_free(blob);
	}

/**
 * ### Revwalking
 *
 * The libgit2 [revision walking api][rw] provides methods to traverse the
 * directed graph created by the parent pointers of the commit objects.
 * Since all commits point back to the commit that came directly before
 * them, you can walk this parentage as a graph and find all the commits
 * that were ancestors of (reachable from) a given starting point.  This
 * can allow you to create `git log` type functionality.
 *
 * [rw]: http://libgit2.github.com/libgit2/#HEAD/group/revwalk
 */
nothrow @nogc
private void revwalking(libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("\n*Revwalking*\n");

		libgit2_d.oid.git_oid oid;
		libgit2_d.oid.git_oid_fromstr(&oid, "5b5b025afb0b4c913b4c338a42934a3863bf3644");

		/**
		 * To use the revwalker, create a new walker, tell it how you want to sort
		 * the output and then push one or more starting points onto the walker.
		 * If you want to emulate the output of `git log` you would push the SHA
		 * of the commit that HEAD points to into the walker and then start
		 * traversing them.  You can also 'hide' commits that you want to stop at
		 * or not see any of their ancestors.  So if you want to emulate `git log
		 * branch1..branch2`, you would push the oid of `branch2` and hide the oid
		 * of `branch1`.
		 */
		libgit2_d.types.git_revwalk* walk;
		libgit2_d.revwalk.git_revwalk_new(&walk, repo);
		libgit2_d.revwalk.git_revwalk_sorting(walk, libgit2_d.revwalk.git_sort_t.GIT_SORT_TOPOLOGICAL | libgit2_d.revwalk.git_sort_t.GIT_SORT_REVERSE);
		libgit2_d.revwalk.git_revwalk_push(walk, &oid);

		/**
		 * Now that we have the starting point pushed onto the walker, we start
		 * asking for ancestors. It will return them in the sorting order we asked
		 * for as commit oids.  We can then lookup and parse the committed pointed
		 * at by the returned OID; note that this operation is specially fast
		 * since the raw contents of the commit object will be cached in memory
		 */
		libgit2_d.types.git_commit* wcommit;

		while ((libgit2_d.revwalk.git_revwalk_next(&oid, walk)) == 0) {
			int error = libgit2_d.commit.git_commit_lookup(&wcommit, repo, &oid);
			.check_error(error, "looking up commit during revwalk");

			const (char)* cmsg = libgit2_d.commit.git_commit_message(wcommit);
			const (libgit2_d.types.git_signature)* cauth = libgit2_d.commit.git_commit_author(wcommit);
			core.stdc.stdio.printf("%s (%s)\n", cmsg, cauth.email);

			libgit2_d.commit.git_commit_free(wcommit);
		}

		/**
		 * Like the other objects, be sure to free the revwalker when you're done
		 * to prevent memory leaks.  Also, make sure that the repository being
		 * walked it not deallocated while the walk is in progress, or it will
		 * result in undefined behavior
		 */
		libgit2_d.revwalk.git_revwalk_free(walk);
	}

/**
 * ### Index File Manipulation *
 * The [index file API][gi] allows you to read, traverse, update and write
 * the Git index file (sometimes thought of as the staging area).
 *
 * [gi]: http://libgit2.github.com/libgit2/#HEAD/group/index
 */
nothrow @nogc
private void index_walking(libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("\n*Index Walking*\n");

		/**
		 * You can either open the index from the standard location in an open
		 * repository, as we're doing here, or you can open and manipulate any
		 * index file with `git_index_open_bare()`. The index for the repository
		 * will be located and loaded from disk.
		 */
		libgit2_d.types.git_index* index;
		libgit2_d.repository.git_repository_index(&index, repo);

		/**
		 * For each entry in the index, you can get a bunch of information
		 * including the SHA (oid), path and mode which map to the tree objects
		 * that are written out.  It also has filesystem properties to help
		 * determine what to inspect for changes (ctime, mtime, dev, ino, uid,
		 * gid, file_size and flags) All these properties are exported publicly in
		 * the `libgit2_d.index.git_index_entry` struct
		 */
		size_t ecount = libgit2_d.index.git_index_entrycount(index);

		for (size_t i = 0; i < ecount; ++i) {
			const (libgit2_d.index.git_index_entry)* e = libgit2_d.index.git_index_get_byindex(index, i);

			core.stdc.stdio.printf("path: %s\n", e.path);
			core.stdc.stdio.printf("mtime: %d\n", cast(int)(e.mtime.seconds));
			core.stdc.stdio.printf("fs: %d\n", cast(int)(e.file_size));
		}

		libgit2_d.index.git_index_free(index);
	}

/**
 * ### References
 *
 * The [reference API][ref] allows you to list, resolve, create and update
 * references such as branches, tags and remote references (everything in
 * the .git/refs directory).
 *
 * [ref]: http://libgit2.github.com/libgit2/#HEAD/group/reference
 */
nothrow @nogc
private void reference_listing(libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("\n*Reference Listing*\n");

		/**
		 * Here we will implement something like `git for-each-ref` simply listing
		 * out all available references and the object SHA they resolve to.
		 *
		 * Now that we have the list of reference names, we can lookup each ref
		 * one at a time and resolve them to the SHA, then print both values out.
		 */

		libgit2_d.strarray.git_strarray ref_list;
		libgit2_d.refs.git_reference_list(&ref_list, repo);

		libgit2_d.types.git_reference* ref_;

		for (uint i = 0; i < ref_list.count; ++i) {
			char[libgit2_d.oid.GIT_OID_HEXSZ + 1] oid_hex = libgit2_d.common.GIT_OID_HEX_ZERO;
			const (char)* refname = ref_list.strings[i];
			libgit2_d.refs.git_reference_lookup(&ref_, repo, refname);

			switch (libgit2_d.refs.git_reference_type(ref_)) {
				case libgit2_d.types.git_reference_t.GIT_REFERENCE_DIRECT:
					libgit2_d.oid.git_oid_fmt(&(oid_hex[0]), libgit2_d.refs.git_reference_target(ref_));
					core.stdc.stdio.printf("%s [%s]\n", refname, &(oid_hex[0]));

					break;

				case libgit2_d.types.git_reference_t.GIT_REFERENCE_SYMBOLIC:
					core.stdc.stdio.printf("%s => %s\n", refname, libgit2_d.refs.git_reference_symbolic_target(ref_));

					break;

				default:
					core.stdc.stdio.fprintf(core.stdc.stdio.stderr, "Unexpected reference type\n");
					core.stdc.stdlib.exit(1);

					break;
			}

			libgit2_d.refs.git_reference_free(ref_);
		}

		libgit2_d.strarray.git_strarray_dispose(&ref_list);
	}

/**
 * ### Config Files
 *
 * The [config API][config] allows you to list and updatee config values
 * in any of the accessible config file locations (system, global, local).
 *
 * [config]: http://libgit2.github.com/libgit2/#HEAD/group/config
 */
nothrow @nogc
private void config_files(const (char)* repo_path, libgit2_d.types.git_repository* repo)

	in
	{
	}

	do
	{
		core.stdc.stdio.printf("\n*Config Listing*\n");

		/**
		 * Open a config object so we can read global values from it.
		 */
		char[256] config_path;
		core.stdc.stdio.sprintf(&(config_path[0]), "%s/config", repo_path);
		libgit2_d.types.git_config* cfg;
		.check_error(libgit2_d.config.git_config_open_ondisk(&cfg, &(config_path[0])), "opening config");

		int autocorrect;

		if (libgit2_d.config.git_config_get_int32(&autocorrect, cfg, "help.autocorrect") == 0) {
			core.stdc.stdio.printf("Autocorrect: %d\n", autocorrect);
		}

		libgit2_d.types.git_config* snap_cfg;
		.check_error(libgit2_d.repository.git_repository_config_snapshot(&snap_cfg, repo), "config snapshot");
		const (char)* email;
		libgit2_d.config.git_config_get_string(&email, snap_cfg, "user.email");
		core.stdc.stdio.printf("Email: %s\n", email);

		int error_code = libgit2_d.config.git_config_get_int32(&autocorrect, cfg, "help.autocorrect");

		switch (error_code) {
			case 0:
				core.stdc.stdio.printf("Autocorrect: %d\n", autocorrect);

				break;

			case libgit2_d.errors.git_error_code.GIT_ENOTFOUND:
				core.stdc.stdio.printf("Autocorrect: Undefined\n");

				break;

			default:
				.check_error(error_code, "get_int32 failed");

				break;
		}

		libgit2_d.config.git_config_free(cfg);

		.check_error(libgit2_d.repository.git_repository_config_snapshot(&snap_cfg, repo), "config snapshot");
		error_code = libgit2_d.config.git_config_get_string(&email, snap_cfg, "user.email");

		switch (error_code) {
			case 0:
				core.stdc.stdio.printf("Email: %s\n", email);

				break;

			case libgit2_d.errors.git_error_code.GIT_ENOTFOUND:
				core.stdc.stdio.printf("Email: Undefined\n");

				break;

			default:
				.check_error(error_code, "get_string failed");

				break;
		}

		libgit2_d.config.git_config_free(snap_cfg);
	}
