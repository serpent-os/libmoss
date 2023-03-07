#!/bin/bash
set -e

echo "Checking that the 'dstep' DLang binding generator is present..."
if ! command -v dstep >/dev/null 2>&1; then
    cat << EOM

Could not find the 'dstep' DLang binding generator?

Please clone the 'dstep' project from

  https://https://github.com/jacob-carlborg/dstep.git

and build the 'dstep' binary from the clone root with 'dub build'.

Finallly, ensure that the newly built 'bin/dstep' is included in your \$PATH.
(see https://github.com/jacob-carlborg/dstep/issues/265)

EOM
fi

echo -e "\nGenerating LMDB $version DLang bindings..."
tmp_file=binding.d
dstep -o "$tmp_file" \
  "/usr/include/lmdb.h" \
  --rename-enum-members=true \
  --package lmdb \
  --comments=true \
  --global-attribute '@nogc' \
  --global-attribute 'nothrow' \
  --global-import 'lmdb.macros' \
  --space-after-function-name=true

cat << EOM > source/lmdb/binding.d
/*  Generated from LMDB headers on $(date -u +'%Y-%m-%d %H:%M UTC') */

$(cat "$tmp_file")
EOM
rm "$tmp_file"

echo "Formatting DLang bindings with scripts/update_format.sh..."
if [[ ! -x scripts/update_format.sh ]]; then
  cat << EOM
Could not format the DLang bindings?

Remember to run 'dfmt -i source/lmdb/binding.d' before committing !!
EOM
    exit 1
fi
scripts/update_format.sh
