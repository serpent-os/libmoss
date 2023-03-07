#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © 2020-2022 Serpent OS Developers
#
# SPDX-License-Identifier: Zlib
#
# serpent-style/sync.sh syncs the git repo from which it is run to the newest
# serpent-style/ submodule and commmits with the message:
#
# "serpent-style: Sync"
set -e

function failMsg ()
{
    echo -e "$*"
    exit 1
}

function hasSerpentStyleSubmodule ()
{
    if [[ -d "${PWD}"/.git/ ]]; then
        if [[ -d "${PWD}"/serpent-style/ ]]; then
            return 0 # "success"
        else
            failMsg "\n${PWD} does not appear to have a serpent-style/ submodule?\n"
        fi
    else
        failMsg "\n${PWD} does not appear to be a git repo?\n"
    fi
}

# Should be run from within a known good git repo
function checkGitStatusClean ()
{
    if [[ -z $(git status --untracked-files=no --porcelain .) ]]; then
        return 0
    else
        failMsg "\n  Git repo ${PWD} contains uncommitted changes?\n  '- Aborting!\n"
    fi
}

hasSerpentStyleSubmodule && checkGitStatusClean

git submodule update --remote --merge serpent-style/ && \
    git add serpent-style && \
    git commit -S -s -m "serpent-style: Sync"
