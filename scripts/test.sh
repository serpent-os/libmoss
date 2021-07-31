#!/bin/bash
set -e
set -x

# COMPILER="dmd"
COMPILER="ldc2"


dub test --compiler="${COMPILER}" --skip-registry=all -v -b debug
