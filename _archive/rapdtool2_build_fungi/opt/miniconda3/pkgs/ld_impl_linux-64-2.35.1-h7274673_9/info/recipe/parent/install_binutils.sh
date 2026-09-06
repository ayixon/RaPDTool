#!/bin/bash

set -e

cd build

make install-strip
export HOST="${ctng_cpu_arch}-conda-linux-gnu"
export OLD_HOST="${ctng_cpu_arch}-${ctng_vendor}-linux-gnu"
mkdir -p $PREFIX/$OLD_HOST/bin
# Remove hardlinks and replace them by softlinks
for tool in addr2line ar as c++filt dwp elfedit gprof ld.bfd ld.gold nm objcopy objdump ranlib readelf size strings strip; do
  rm -rf $PREFIX/$HOST/bin/$tool || true
  ln -s $PREFIX/bin/$HOST-$tool $PREFIX/$HOST/bin/$tool || true;
  ln -s $PREFIX/bin/$HOST-$tool $PREFIX/$OLD_HOST/bin/$tool || true;
  ln -s $PREFIX/bin/$HOST-$tool $PREFIX/bin/$OLD_HOST-$tool || true;
done

rm $PREFIX/bin/$HOST-ld || true;
rm $PREFIX/bin/$OLD_HOST-ld || true;
rm $PREFIX/$OLD_HOST/bin/ld || true;
rm $PREFIX/$HOST/bin/ld || true;

#ln -s $PREFIX/$HOST $PREFIX/$OLD_HOST
