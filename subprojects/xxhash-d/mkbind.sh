#!/bin/bash
set -e
set -x

dstep -o binding.d \
        /usr/include/xxhash.h \
        --rename-enum-members=true \
        --package xxhash \
        --comments=false \
        --global-attribute '@nogc' \
        --global-attribute 'nothrow'

cp binding.d source/xxhash/binding.d
rm binding.d
