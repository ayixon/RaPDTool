#!/bin/bash

if [[ $target_platform =~ linux.* ]]; then
  export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
fi

# linux-aarch64 activations fails to set `ar` tool. This can be
# removed when ctng-compiler-activation is corrected.
if [[ "${target_platform}" == linux-aarch64 ]]; then
  if [[ -n "$AR" ]]; then
      CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_AR=${AR}"
  fi
fi

for _shared in OFF ON; do
  mkdir build-${_shared}
  pushd build-${_shared}
    cmake ${CMAKE_ARGS}                     \
          -DCMAKE_INSTALL_PREFIX=${PREFIX}  \
          -DBUILD_SHARED_LIBS=${_shared}    \
          -DCMAKE_INSTALL_LIBDIR=lib        \
          ..
    make -j${CPU_COUNT} ${VERBOSE_CM}
    make install
  popd
done
