#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
#
# SPDX-License-Identifier: Zlib
#
# Git pre-commit hook for serpent-style'd projects.
#
# Inspired by examples from:
#
#   https://codeinthehole.com/tips/tips-for-using-a-git-pre-commit-hook/
#

#set -x

# This assumes that directories ending in .d are never added...
D_FILES='\.d$'

function noisyFail ()
{
    if [[ -z "$1" ]]; then
       echo ""
       echo "\033[1;31mERROR:\033[0m\033[1m  No message parameter specified for noisyFail?\033[0m"
       echo ""
       exit 1
    fi
    # set up terminal colours
    BOLDRED="\033[1;31m"
    BOLD="\033[1m"
    RESET="\033[0m"
    ERRMSG="${BOLDRED}ERROR:${RESET}${BOLD}  ${1}${RESET}"
    echo ""
    echo -e "${ERRMSG}"
    echo ""
    exit 1
}

function checkForTools ()
{
    local TOOLS=(
        gawk
        grep
        sed
        xargs
    )
    local MISSING_TOOLS=""
    echo -e "\nChecking for tools used by serpent-style git pre-commit hook..."
    for tool in "${TOOLS[@]}"; do
        command -v "${tool}" > /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            MISSING_TOOLS+="  ${tool}\n"
        else
            echo -e "'- found ${tool}"
        fi
    done
    if [[ ! -z "${MISSING_TOOLS}" ]]; then
        noisyFail "
  Missing tools:
  ${MISSING_TOOLS}
  Git pre-commit hook aborted.
"
    else
        echo ""
    fi
}

# Ignore vendor code, since we only aim to consume it
#
# Alse ignore deleted files in 'git diff --cached --name-only' by adding
# '--diff-filter=d'
#
function rejectForbiddenPatterns ()
{
    git diff --cached --name-only --diff-filter=d | \
        grep -E "${D_FILES}" | \
        grep -Ev '^moss-vendor' | \
        xargs gawk -- '
# we need this for exit status
BEGIN { matches = 0; }

function error(msg) {
    print FILENAME ":" FNR ":";
    print ">" $0 "<";
    print ">> " msg "\n";
    matches += 1;
}

# Illegal patterns
# only match lines that are not commented out (we use 4 space indents)
# each line of Dlang code is matched against all the patterns below in the order listed
#
# Use a "where, what, how-to-fix (why)" format for usability

# disallow writefln run-time format strings
/^[ ]*writefln\(/ {
    error("Use writefln! instead of writefln() (compile time format string check)");
}

# disallow logger run-time format strings
/^[ ]*(log|trace|info|warning|error|critical|fatal)f/ {
    error("Use e.g. info(format! instead (compile time format string check)");
}

# buildPath has been shown to be slow
/^[ ]*buildPath/ {
    error("Use .join or joinPath instead of buildPath (speedup)");
}

# exit 1 on illegal patterns found
END {
    if (matches != 0) {
        print "Found " matches " illegal Dlang patterns.";
        exit (matches != 0)
    }
}
' \
       || noisyFail "
  COMMIT REJECTED
  -- Found illegal Dlang code patterns.
  >> Please remove them before committing!"
}

# list of enabled functions
checkForTools && rejectForbiddenPatterns
