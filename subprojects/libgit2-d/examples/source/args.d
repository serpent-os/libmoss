/**
 * Argument-processing helper structure
 */
module libgit2_d.example.args;


private static import core.stdc.stdlib;
private static import core.stdc.string;
private static import libgit2_d.example.common;
private static import libgit2_d.strarray;
private static import std.bitmanip;

package:

struct args_info
{
	int argc;
	char** argv;
	int pos;

	/**
	 * < Did we see a -- separator
	 */
	mixin
	(
		std.bitmanip.bitfields!
		(
			int, "opts_done", 1,
			int, "not_used", 7
		)
	);
}

pragma(inline, true)
pure nothrow @safe @nogc
.args_info ARGS_INFO_INIT(int argc, char** argv)

	do
	{
		.args_info OUTPUT =
		{
			argc: argc,
			argv: argv,
			pos: 0,
		};

		OUTPUT.opts_done = 0;

		return OUTPUT;
	}

//#define ARGS_CURRENT(args) args.argv[args.pos]

/**
 * Check if a string has the given prefix.  Returns 0 if not prefixed
 * or the length of the prefix if it is.
 */
nothrow @nogc
size_t is_prefixed(const (char)* str, const (char)* pfx)

	in
	{
	}

	do
	{
		size_t len = core.stdc.string.strlen(pfx);

		return (core.stdc.string.strncmp(str, pfx, len)) ? (0) : (len);
	}

/**
 * Check current `args` entry against `opt` string.  If it matches
 * exactly, take the next arg as a string; if it matches as a prefix with
 * an equal sign, take the remainder as a string; if value not supplied,
 * default value `def` will be given. otherwise return 0.
 */
nothrow @nogc
int optional_str_arg(const (char)** out_, libgit2_d.example.args.args_info* args, const (char)* opt, const (char)* def)

	in
	{
	}

	do
	{
		const (char)* found = args.argv[args.pos];
		size_t len = .is_prefixed(found, opt);

		if (!len) {
			return 0;
		}

		if (!found[len]) {
			if ((args.pos + 1) == args.argc) {
				*out_ = def;

				return 1;
			}

			args.pos += 1;
			*out_ = args.argv[args.pos];

			return 1;
		}

		if (found[len] == '=') {
			*out_ = found + len + 1;

			return 1;
		}

		return 0;
	}

/**
 * Check current `args` entry against `opt` string.  If it matches
 * exactly, take the next arg as a string; if it matches as a prefix with
 * an equal sign, take the remainder as a string; otherwise return 0.
 */
nothrow @nogc
int match_str_arg(const (char)** out_, libgit2_d.example.args.args_info* args, const (char)* opt)

	in
	{
	}

	do
	{
		const (char)* found = args.argv[args.pos];
		size_t len = .is_prefixed(found, opt);

		if (!len) {
			return 0;
		}

		if (!found[len]) {
			if ((args.pos + 1) == args.argc) {
				libgit2_d.example.common.fatal("expected value following argument", opt);
			}

			args.pos += 1;
			*out_ = args.argv[args.pos];

			return 1;
		}

		if (found[len] == '=') {
			*out_ = found + len + 1;

			return 1;
		}

		return 0;
	}

nothrow @nogc
private const (char)* match_numeric_arg(libgit2_d.example.args.args_info* args, const (char)* opt)

	in
	{
	}

	do
	{
		const (char)* found = args.argv[args.pos];
		size_t len = .is_prefixed(found, opt);

		if (!len) {
			return null;
		}

		if (!found[len]) {
			if ((args.pos + 1) == args.argc) {
				libgit2_d.example.common.fatal("expected numeric value following argument", opt);
			}

			args.pos += 1;
			found = args.argv[args.pos];
		} else {
			found = found + len;

			if (*found == '=') {
				found++;
			}
		}

		return found;
	}

/**
 * Check current `args` entry against `opt` string parsing as uint16.  If
 * `opt` matches exactly, take the next arg as a uint16_t value; if `opt`
 * is a prefix (equal sign optional), take the remainder of the arg as a
 * uint16_t value; otherwise return 0.
 */
nothrow @nogc
int match_uint16_arg(ushort* out_, libgit2_d.example.args.args_info* args, const (char)* opt)

	in
	{
	}

	do
	{
		const (char)* found = .match_numeric_arg(args, opt);

		if (found == null) {
			return 0;
		}

		const (char)* endptr = null;
		ushort val = cast(ushort)(core.stdc.stdlib.strtoul(found, &endptr, 0));

		if ((endptr == null) || (*endptr != '\0')) {
			libgit2_d.example.common.fatal("expected number after argument", opt);
		}

		if (out_ != null) {
			*out_ = val;
		}

		return 1;
	}

/**
 * Check current `args` entry against `opt` string parsing as uint32.  If
 * `opt` matches exactly, take the next arg as a uint16_t value; if `opt`
 * is a prefix (equal sign optional), take the remainder of the arg as a
 * uint32_t value; otherwise return 0.
 */
nothrow @nogc
int match_uint32_arg(uint* out_, libgit2_d.example.args.args_info* args, const (char)* opt)

	in
	{
	}

	do
	{
		const (char)* found = .match_numeric_arg(args, opt);

		if (found == null) {
			return 0;
		}

		const (char)* endptr = null;

		ushort val = cast(ushort)(core.stdc.stdlib.strtoul(found, &endptr, 0));

		if ((endptr == null) || (*endptr != '\0')) {
			libgit2_d.example.common.fatal("expected number after argument", opt);
		}

		if (out_ != null) {
			*out_ = val;
		}

		return 1;
	}

nothrow @nogc
private int match_int_internal(int* out_, const (char)* str, int allow_negative, const (char)* opt)

	in
	{
	}

	do
	{
		const (char)* endptr = null;
		int val = cast(int)(core.stdc.stdlib.strtol(str, &endptr, 10));

		if ((endptr == null) || (*endptr != '\0')) {
			libgit2_d.example.common.fatal("expected number", opt);
		} else if ((val < 0) && (!allow_negative)) {
			libgit2_d.example.common.fatal("negative values are not allowed", opt);
		}

		if (out_ != null) {
			*out_ = val;
		}

		return 1;
	}

/**
 * Check current `args` entry against a "bool" `opt` (ie. --[no-]progress).
 * If `opt` matches positively, out will be set to 1, or if `opt` matches
 * negatively, out will be set to 0, and in both cases 1 will be returned.
 * If neither the positive or the negative form of opt matched, out will be -1,
 * and 0 will be returned.
 */
nothrow @nogc
int match_bool_arg(int* out_, libgit2_d.example.args.args_info* args, const (char)* opt)

	in
	{
	}

	do
	{
		const (char)* found = args.argv[args.pos];

		if (!core.stdc.string.strcmp(found, opt)) {
			*out_ = 1;

			return 1;
		}

		if ((!core.stdc.string.strncmp(found, "--no-", core.stdc.string.strlen("--no-"))) && (!core.stdc.string.strcmp(found + core.stdc.string.strlen("--no-"), opt + 2))) {
			*out_ = 0;

			return 1;
		}

		*out_ = -1;

		return 0;
	}

/**
 * Match an integer string, returning 1 if matched, 0 if not.
 */
nothrow @nogc
int is_integer(int* out_, const (char)* str, int allow_negative)

	in
	{
	}

	do
	{
		return .match_int_internal(out_, str, allow_negative, null);
	}

/**
 * Check current `args` entry against `opt` string parsing as int.  If
 * `opt` matches exactly, take the next arg as an int value; if it matches
 * as a prefix (equal sign optional), take the remainder of the arg as a
 * int value; otherwise return 0.
 */
nothrow @nogc
int match_int_arg(int* out_, libgit2_d.example.args.args_info* args, const (char)* opt, int allow_negative)

	in
	{
	}

	do
	{
		const (char)* found = .match_numeric_arg(args, opt);

		if (found == null) {
			return 0;
		}

		return .match_int_internal(out_, found, allow_negative, opt);
	}

/**
 * Check if we're processing past the single -- separator
 */
nothrow @nogc
int match_arg_separator(libgit2_d.example.args.args_info* args)

	in
	{
	}

	do
	{
		if (args.opts_done) {
			return 1;
		}

		if (core.stdc.string.strcmp(args.argv[args.pos], "--") != 0) {
			return 0;
		}

		args.opts_done = 1;
		args.pos++;

		return 1;
	}

/**
 * Consume all remaining arguments in a git_strarray
 */
nothrow @nogc
void strarray_from_args(libgit2_d.strarray.git_strarray* array, libgit2_d.example.args.args_info* args)

	in
	{
	}

	do
	{
		array.count = args.argc - args.pos;
		array.strings = cast(char**)(core.stdc.stdlib.calloc(array.count, (char*).sizeof));
		assert(array.strings != null);

		for (size_t i = 0; args.pos < args.argc; ++args.pos) {
			array.strings[i++] = args.argv[args.pos];
		}

		args.pos = args.argc;
	}
