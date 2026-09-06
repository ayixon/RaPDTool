#!/bin/bash

set -e


#pushd ${BUILD_PREFIX}/bin
#  for fn in "${BUILD}-"*; do
#    new_fn=${fn//${BUILD}-/}
#    echo "Creating symlink from ${fn} to ${new_fn}"
#    ln -sf "${fn}" "${new_fn}"
#    varname=$(basename "${new_fn}" | tr a-z A-Z | sed "s/+/X/g" | sed "s/\./_/g" | sed "s/-/_/g")
#    echo "$varname $CC"
#    printf -v "$varname" "$BUILD_PREFIX/bin/${new_fn}"
#  done
#popd

for file in ./crosstool_ng/packages/binutils/2.35/*.patch; do
  patch -p1 < $file;
done

mkdir build
cd build

if [[ "$target_platform" == "osx-64" ]]; then
  export CPPFLAGS="$CPPFLAGS -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
  export CFLAGS="$CFLAGS -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
  export CXXFLAGS="$CXXFLAGS -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
  export LDFLAGS="$LDFLAGS -Wl,-pie -Wl,-headerpad_max_install_names -Wl,-dead_strip_dylibs"
fi
export LDFLAGS="$LDFLAGS -Wl,-rpath,$PREFIX/lib"

export HOST="${ctng_cpu_arch}-conda-linux-gnu"

../configure \
  --prefix="$PREFIX" \
  --target=$HOST \
  --enable-ld=default \
  --enable-gold=yes \
  --enable-plugins \
  --disable-multilib \
  --disable-sim \
  --disable-gdb \
  --disable-nls \
  --enable-default-pie \
  --with-sysroot=$PREFIX/$HOST/sysroot \

make -j${CPU_COUNT}

#exit 1
