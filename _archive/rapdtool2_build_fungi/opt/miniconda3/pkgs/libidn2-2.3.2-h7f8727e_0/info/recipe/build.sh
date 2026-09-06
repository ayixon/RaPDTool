#!/bin/bash

set -ex
set -o pipefail

./configure --prefix="${PREFIX}" \
    CC_FOR_BUILD="${CC}" \
    --enable-shared \
    --disable-static \
    --disable-doc \
    --disable-gtk-doc \
    --disable-gtk-doc-html \
    --disable-gtk-doc-pdf \
    --disable-nls \
    --disable-code-coverage \
    --without-libiconv-prefix \
    --without-libintl-prefix \
    --without-gcov

make
make check
make install

# Save some space
rm -rf "${PREFIX}/share/info"
rm -rf "${PREFIX}/share/man"
rm -rf "${PREFIX}/share/gtk-doc"
