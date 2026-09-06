#!/bin/bash

set -x

# numpy distutils don't use the env variables.
if [[ ! -f $BUILD_PREFIX/bin/ranlib ]]; then
    ln -s $RANLIB $BUILD_PREFIX/bin/ranlib
    ln -s $AR $BUILD_PREFIX/bin/ar
fi

cat > site.cfg <<EOF
[DEFAULT]
library_dirs = $PREFIX/lib
include_dirs = $PREFIX/include

[lapack]
libraries = lapack,blas

[blas]
libraries = cblas,blas
EOF

export NPY_LAPACK_ORDER=lapack
export NPY_BLAS_ORDER=blas

$PYTHON -m pip install --no-deps --ignore-installed -v .
