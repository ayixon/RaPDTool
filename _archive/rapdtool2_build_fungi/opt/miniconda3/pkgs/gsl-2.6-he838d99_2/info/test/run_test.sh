

set -ex



gsl-config --prefix
ls -al $PREFIX/lib/libgsl${SHLIB_EXT}
ls -al $PREFIX/lib/libgslcblas${SHLIB_EXT}
ls -al $PREFIX/lib/libgslcblas.so.0
ls -al $PREFIX/lib/libgsl.so.*
exit 0
