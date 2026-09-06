#!/bin/bash

CHOST="${ctng_cpu_arch}-conda-linux-gnu"

for tool in addr2line ar as c++filt dwp elfedit gprof ld ld.bfd ld.gold nm objcopy objdump ranlib readelf size strings strip; do
  rm -f $PREFIX/bin/$CHOST-$tool || true
  touch $PREFIX/bin/$CHOST-$tool
  # On s390x dwp and gold support seems not to be present
  ln -s $PREFIX/bin/$CHOST-$tool $PREFIX/bin/$tool || true
done

# Gold support is not present on s390x
ln -s "$PREFIX/bin/ld.gold" "$PREFIX/bin/gold" || true
