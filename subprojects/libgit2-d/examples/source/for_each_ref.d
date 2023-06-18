module libgit2_d.example.for_each_ref;


private static import core.stdc.stdio;
private static import libgit2_d.example.common;
private static import libgit2_d.object;
private static import libgit2_d.oid;
private static import libgit2_d.refs;
private static import libgit2_d.types;

package:

extern (C)
nothrow @nogc
private int show_ref(libgit2_d.types.git_reference* ref_, void* data)

	in
	{
	}

	do
	{
		libgit2_d.types.git_reference* resolved = null;

		if (libgit2_d.refs.git_reference_type(ref_) == libgit2_d.types.git_reference_t.GIT_REFERENCE_SYMBOLIC) {
			libgit2_d.example.common.check_lg2(libgit2_d.refs.git_reference_resolve(&resolved, ref_), "Unable to resolve symbolic reference", libgit2_d.refs.git_reference_name(ref_));
		}

		const (libgit2_d.oid.git_oid)* oid = libgit2_d.refs.git_reference_target((resolved) ? (resolved) : (ref_));
		char[libgit2_d.oid.GIT_OID_HEXSZ + 1] hex;
		libgit2_d.oid.git_oid_fmt(&(hex[0]), oid);
		hex[libgit2_d.oid.GIT_OID_HEXSZ] = 0;
		libgit2_d.types.git_object* obj;
		libgit2_d.types.git_repository* repo = cast(libgit2_d.types.git_repository*)(data);
		libgit2_d.example.common.check_lg2(libgit2_d.object.git_object_lookup(&obj, repo, oid, libgit2_d.types.git_object_t.GIT_OBJECT_ANY), "Unable to lookup object", &(hex[0]));

		core.stdc.stdio.printf("%s %-6s\t%s\n", &(hex[0]), libgit2_d.object.git_object_type2string(libgit2_d.object.git_object_type(obj)), libgit2_d.refs.git_reference_name(ref_));

		if (resolved) {
			libgit2_d.refs.git_reference_free(resolved);
		}

		return 0;
	}

extern (C)
nothrow @nogc
public int lg2_for_each_ref(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		//cast(void)(argv);

		if (argc != 1) {
			libgit2_d.example.common.fatal("Sorry, no for-each-ref options supported yet", null);
		}

		libgit2_d.example.common.check_lg2(libgit2_d.refs.git_reference_foreach(repo, &.show_ref, repo), "Could not iterate over references", null);

		return 0;
	}
