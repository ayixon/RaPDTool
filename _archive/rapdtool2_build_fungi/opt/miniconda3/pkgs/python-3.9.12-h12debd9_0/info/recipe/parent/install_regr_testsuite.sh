#!/usr/bin/env bash

set -eux
VER=${PKG_VERSION%.*}
pushd ${SRC_DIR}/test.backup
cp -rf * ${PREFIX}/lib/python${VER}/
