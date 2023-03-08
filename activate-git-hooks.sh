#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © 2020-2023 Serpent OS Developers
#
# SPDX-License-Identifier: Zlib
#

function failMsg()
{
    echo -e "$*"
    exit 1
}

# ensure that we are running from the root of a clean .git repo
[[ -z $(git status --untracked-files=no --porcelain .) ]] || failMsg "Ensure git tree is clean before running this script"
test -e .git || failMsg "Please run from the root of a Serpent OS git project"

# set up git hooks unconditionally
if [[ ! -d .git/hooks ]]; then
    install -D -d -m 00755 .git/hooks
fi
# Link pre-commit hook in (using -r avoids dangling symlink)
ln -rsvf serpent-style/git-pre-commit-hook.sh .git/hooks/pre-commit

git status
