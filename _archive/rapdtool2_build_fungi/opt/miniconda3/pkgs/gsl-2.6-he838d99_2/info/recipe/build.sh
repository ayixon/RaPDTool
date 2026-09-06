#!/bin/bash

set -e
set -x

# Don't link to libgslcblas on windows
sed -i.bak "s/GSL_LIBADD=/GSL_LIBADD2=/g" configure.ac

rm -rf config.*
autoreconf -i
chmod +x configure

# https://github.com/conda-forge/gsl-feedstock/issues/34#issuecomment-449305702
if [[ "$target_platform" == win* ]]; then
    export CPPFLAGS="$CPPFLAGS -DGSL_DLL -DWIN32"
    export CXXFLAGS="$CXXFLAGS -DGSL_DLL -DWIN32"
    export CFLAGS="$CFLAGS -DGSL_DLL -DWIN32"
    export LDFLAGS="$LDFLAGS -lcblas"
    cp $RECIPE_DIR/getopt.h .
    ./configure --prefix=${PREFIX} \
                --disable-static || (cat config.log && exit 1)
    cat config.log
else
    export LIBS="-lcblas -lm"
    ./configure --prefix=${PREFIX}  \
                --host=${HOST} || (cat config.log && exit 1)
fi

[[ "$target_platform" == "win-64" ]] && patch_libtool


# Don't link with the convenience libraries as they don't contain __imp_*
if [[ "$target_platform" == win* ]]; then
    make -j${CPU_COUNT} -k || true
    for f in $(find . -wholename "./*/.libs/*.lib" -not -wholename "./blas/*"  -not -wholename "./cblas/*"); do
        cp .libs/gsl.dll.lib $f
    done
    make -j${CPU_COUNT}
    make install
    # There are some numerical issues with the tests as well as build issues.
    # So disable for now. CMake build didn't run tests either.
    make check -j${CPU_COUNT} -k || true
    echo "no check on windows"
else
    make -j${CPU_COUNT}
    if [[ "$CONDA_BUILD_CROSS_COMPILATION" != "1" ]]; then
    for f in $(find * -name "test.c"); do
        TEST_DIR=$(dirname $f)
        pushd $TEST_DIR;
        SKIP=false
        # See: https://savannah.gnu.org/bugs/index.php?56843
        if [[ "$target_platform" == "linux-aarch64" && "$TEST_DIR" == "spmatrix" ]]; then
            SKIP=true
        fi
        if [[ "$target_platform" == "linux-ppc64le" ]]; then
            if [[ "$TEST_DIR" == "linalg" || "$TEST_DIR" == "multilarge_nlinear" || "$TEST_DIR" == "spmatrix" ]]; then
                SKIP=true
            fi
        fi
        if [[ "$SKIP" == true ]]; then
            make check || true;
        else
            make check;
        fi
        popd;
    done
    fi
    make install
fi

ls -al "$PREFIX"/lib
ls -al "$PREFIX"/bin

if [[ "$target_platform" == osx* ]]; then
    ln -sf "libcblas.3.dylib" "$PREFIX/lib/libgslcblas.dylib"
    ln -sf "libcblas.3.dylib" "$PREFIX/lib/libgslcblas.0.dylib"
    rm "$PREFIX/lib/libcblas.3.dylib"
    touch "$PREFIX/lib/libcblas.3.dylib"
elif [[ "$target_platform" == linux* ]]; then
    ln -sf "libcblas.so.3" "$PREFIX/lib/libgslcblas.so"
    ln -sf "libcblas.so.3" "$PREFIX/lib/libgslcblas.so.0"
    rm "$PREFIX/lib/libcblas.so.3"
    touch "$PREFIX/lib/libcblas.so.3"
elif [[ "$target_platform" == win* ]]; then
    rm "$PREFIX/lib/gslcblas.dll.lib"
    rm "$PREFIX/bin/gslcblas-0.dll"
    cp "$PREFIX/lib/cblas.lib" "$PREFIX/lib/gslcblas.lib"
fi
