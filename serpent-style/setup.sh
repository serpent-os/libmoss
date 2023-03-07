#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
#
# SPDX-License-Identifier: Zlib
#
set -e

DeprecatedFiles=("scripts/update_format.sh", "LICENSE")
LinkFiles=(".editorconfig" "dscanner.ini")
NukedAny=0

function failMsg()
{
    echo -e "$*"
    exit 1
}

[[ -z $(git status --untracked-files=no --porcelain .) ]] || failMsg "Ensure git tree is clean before running this script"
test -e .git || failMsg "Please run from the root of a Serpent OS git project"

# Deprecate old scripts
for depr in ${DeprecatedFiles[@]}; do
    if [[ -e "${depr}" ]]; then
        echo "Removing deprecated asset: ${depr}"
        git rm "${depr}"
        NukedAny=1
    fi
done

if [[ "${NukedAny}" == "1" ]]; then
    echo "Commiting changes..."
    git commit -S -s -m "serpent-style: Remove deprecated assets"
fi

# Forcibly link the files in
for link in ${LinkFiles[@]}; do
    ln -svf "serpent-style/${link}" "."
done

# Add REUSE-compatible license directory
mkdir -pv ./LICENSES/
cp -vf serpent-style/LICENSES/Zlib.txt ./LICENSES/
git add LICENSES/

# Link pre-commit hook in (using -r avoids dangling symlink)
if [[ ! -d .git/hooks ]]; then
    install -D -d -m 00755 .git/hooks
fi
ln -rsvf serpent-style/git-pre-commit-hook.sh .git/hooks/pre-commit

git status

echo -e "\nPlease 'git add' any new links/files added by serpent-style/ and commit them.\n"
