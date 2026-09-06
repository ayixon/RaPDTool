#!/usr/bin/env bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./build-aux

./configure --disable-dependency-tracking --disable-silent-rules --prefix=${PREFIX}
make
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
  if [[ "${target_platform}" == linux-* ]]; then
    make check || true
  else
    make check
  fi
fi
make install
