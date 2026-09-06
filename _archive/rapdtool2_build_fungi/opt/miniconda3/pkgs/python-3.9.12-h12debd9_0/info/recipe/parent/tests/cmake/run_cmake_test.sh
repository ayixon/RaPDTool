#!/usr/bin/env bash

set +e
set -x

CMAKE_DBG="trace --debug-find --debug-output --debug-trycompile"
CMAKE_DBG=--debug-find
cmake -G"Unix Makefiles" -DPY_VER=${1} ${CMAKE_DBG} -DCMAKE_OSX_SYSROOT=${CONDA_BUILD_SYSROOT} -DCMAKE_C_FLAGS="${CFLAGS}" .
make
