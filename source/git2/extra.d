/**
 * This file contains overloaded functions that serves to make using libgit2
 * easier. Most (if not all) of them are still extern(C) as they only differ
 * from their original functions solely because of annotated parameters or
 * default parameters.
 */
module git2.extra;

import git2.bindings;

@safe:
extern(C):

int git_remote_fetch (
    scope git_remote* remote,
    scope ref git_strarray refspecs,
    scope git_fetch_options* opts,
    const(char)* reflog_message = null);

int git_remote_fetch (
    scope git_remote* remote,
    scope git_strarray* refspecs,
    scope ref git_fetch_options opts,
    const(char)* reflog_message = null);

int git_remote_fetch (
    scope git_remote* remote,
    scope ref git_strarray refspecs,
    scope ref git_fetch_options opts,
    const(char)* reflog_message = null);

int git_clone (
    scope out git_repository* out_,
    const(char)* url,
    const(char)* local_path,
    scope ref git_clone_options options);
