/*
 * libgit2 "config" example - shows how to use the config API
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
module libgit2_d.example.config;


private static import core.stdc.stdio;
private static import libgit2_d.config;
private static import libgit2_d.errors;
private static import libgit2_d.repository;
private static import libgit2_d.types;

package:

nothrow @nogc
private int config_get(libgit2_d.types.git_config* cfg, const (char)* key)

	in
	{
	}

	do
	{
		libgit2_d.config.git_config_entry* entry;
		int error = libgit2_d.config.git_config_get_entry(&entry, cfg, key);

		if (error < 0) {
			if (error != libgit2_d.errors.git_error_code.GIT_ENOTFOUND) {
				core.stdc.stdio.printf("Unable to get configuration: %s\n", libgit2_d.errors.git_error_last().message);
			}

			return 1;
		}

		core.stdc.stdio.puts(entry.value);

		return 0;
	}

nothrow @nogc
private int config_set(libgit2_d.types.git_config* cfg, const (char)* key, const (char)* value)

	in
	{
	}

	do
	{
		if (libgit2_d.config.git_config_set_string(cfg, key, value) < 0) {
			core.stdc.stdio.printf("Unable to set configuration: %s\n", libgit2_d.errors.git_error_last().message);

			return 1;
		}

		return 0;
	}

extern (C)
nothrow @nogc
public int lg2_config(libgit2_d.types.git_repository* repo, int argc, char** argv)

	in
	{
	}

	do
	{
		libgit2_d.types.git_config* cfg;
		int error = libgit2_d.repository.git_repository_config(&cfg, repo);

		if (error < 0) {
			core.stdc.stdio.printf("Unable to obtain repository config: %s\n", libgit2_d.errors.git_error_last().message);

			return error;
		}

		if (argc == 2) {
			error = .config_get(cfg, argv[1]);
		} else if (argc == 3) {
			error = .config_set(cfg, argv[1], argv[2]);
		} else {
			core.stdc.stdio.printf("USAGE: %s config <KEY> [<VALUE>]\n", argv[0]);
			error = 1;
		}

		return error;
	}
