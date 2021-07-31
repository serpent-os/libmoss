#!/bin/bash
set -e
set -x

MODE="debug"

# Override by setting COMPILER=dmd in environment
if [[ -z "${COMPILER}" ]]; then
	export COMPILER="ldc2"
fi

if [[ ! -z "$1" ]]; then
    MODE="$1"
fi

function testProject()
{
    dub test --parallel -b "${MODE}" --compiler="${COMPILER}" --skip-registry=all -v --force
}

if [[ "$MODE" == "optimized" ]]; then
    MODE="release"
    testProject
elif [[ "$MODE" == "debug" ]]; then
    testProject
else
    echo "Unknown build mode"
    exit 1
fi

