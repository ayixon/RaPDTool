set -e -x

CHOST=$(${SRC_DIR}/.build/*-*-*-*/build/build-cc-gcc-final/gcc/xgcc -dumpmachine)

# libtool wants to use ranlib that is here, macOS install doesn't grok -t etc
# .. do we need this scoped over the whole file though?
export PATH=${SRC_DIR}/gcc_built/bin:${SRC_DIR}/.build/${CHOST}/buildtools/bin:${SRC_DIR}/.build/tools/bin:${PATH}

pushd ${SRC_DIR}/.build/${CHOST}/build/build-cc-gcc-final/

  make -C ${CHOST}/libgcc prefix=${PREFIX} install-shared

  # TODO :: Also do this for libgfortran (and libstdc++ too probably?)
  sed -i.bak 's/.*cannot install.*/func_warning "Ignoring libtool error about cannot install to a directory not ending in"/' \
             ${CHOST}/libsanitizer/libtool
  for lib in libatomic libgomp libquadmath libitm libvtv libsanitizer/{a,l,ub,t}san; do
    # TODO :: Also do this for libgfortran (and libstdc++ too probably?)
    if [[ -f ${CHOST}/${lib}/libtool ]]; then
      sed -i.bak 's/.*cannot install.*/func_warning "Ignoring libtool error about cannot install to a directory not ending in"/' \
                 ${CHOST}/${lib}/libtool
    fi
    if [[ -d ${CHOST}/${lib} ]]; then
      make -C ${CHOST}/${lib} prefix=${PREFIX} install-toolexeclibLTLIBRARIES
      make -C ${CHOST}/${lib} prefix=${PREFIX} install-nodist_fincludeHEADERS || true
    fi
  done

  for lib in libgomp libquadmath; do
    if [[ -d ${CHOST}/${lib} ]]; then
      make -C ${CHOST}/${lib} prefix=${PREFIX} install-info
    fi
  done

popd

mkdir -p ${PREFIX}/lib

# no static libs
find ${PREFIX}/${CHOST}/lib -name "*\.a" -exec rm -rf {} \;
# no libtool files
find ${PREFIX}/${CHOST}/lib -name "*\.la" -exec rm -rf {} \;

if [[ "${PKG_NAME}" != gcc_impl* ]]; then
  mv ${PREFIX}/${CHOST}/lib/* ${PREFIX}/lib
  # clean up empty folder
  rm -rf ${PREFIX}/lib/gcc

  # Install Runtime Library Exception
  install -Dm644 ${SRC_DIR}/.build/src/gcc-${ctng_gcc}/COPYING.RUNTIME \
        ${PREFIX}/share/licenses/gcc-libs/RUNTIME.LIBRARY.EXCEPTION
fi
