set -e -x

CHOST=$(${SRC_DIR}/.build/*-*-*-*/build/build-cc-gcc-final/gcc/xgcc -dumpmachine)

pushd ${SRC_DIR}/.build/${CHOST}/build/build-binutils-host-*
  PATH=${SRC_DIR}/.build/${CHOST}/buildtools/bin:$PATH \
  make prefix=${PREFIX} install-strip
popd

# clean up the sysroot
for tool in ar as ld ld.bfd ld.gold nm objcopy objdump ranlib readelf stri; do
  rm -rf $PREFIX/$CHOST/bin/$tool
  ln -s $PREFIX/bin/$CHOST-$tool $PREFIX/$CHOST/bin/$tool || true;
done

# Copy the liblto_plugin.so from the build tree. This is something of a hack and, on OSes other
# than the build OS, may cause segfaults. This plugin is used by gcc-ar, gcc-as and gcc-ranlib.
pushd ${SRC_DIR}/.build/*-*-*-*/build/build-cc-gcc-core-pass-2/gcc/
  mkdir -p ${PREFIX}/libexec/gcc/${CHOST}/${TOP_PKG_VERSION}/
  cp -a liblto* ${PREFIX}/libexec/gcc/${CHOST}/${TOP_PKG_VERSION}/
popd

source ${RECIPE_DIR}/make_tool_links.sh
