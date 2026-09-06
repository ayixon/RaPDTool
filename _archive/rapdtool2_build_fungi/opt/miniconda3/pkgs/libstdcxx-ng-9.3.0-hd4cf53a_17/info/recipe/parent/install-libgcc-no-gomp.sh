set -e -x

CHOST=$(${SRC_DIR}/.build/*-*-*-*/build/build-cc-gcc-final/gcc/xgcc -dumpmachine)

# we have to remove existing links/files so that the libgcc install works
rm -rf ${PREFIX}/lib/*
rm -rf ${PREFIX}/share/*
rm -f ${PREFIX}/${CHOST}/sysroot/lib/libgomp*

# now run install of libgcc
# this reinstalls the wrong symlinks for openmp
source ${RECIPE_DIR}/install-libgcc.sh

# remove and relink things for openmp
rm -f ${PREFIX}/lib/libgomp.so
rm -f ${PREFIX}/${CHOST}/sysroot/lib/libgomp.so
rm -f ${PREFIX}/lib/libgomp.so.${libgomp_ver:0:1}
rm -f ${PREFIX}/${CHOST}/sysroot/lib/libgomp.so.${libgomp_ver:0:1}
rm -f ${PREFIX}/${CHOST}/sysroot/lib/libgomp.so.${libgomp_ver}

# (re)make the right links
# note that this code is remaking more links than the ones we want in this
# package but that is ok
pushd ${PREFIX}/lib
ln -s libgomp.so.${libgomp_ver} libgomp.so.${libgomp_ver:0:1}
popd
