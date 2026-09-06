#!/bin/bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/libtool/build-aux/config.* .

# need macosx-version-min flags set in cflags and not cppflags
export CFLAGS="$CFLAGS $CPPFLAGS"

./configure \
    --prefix=${PREFIX} \
    --host=${HOST} \
    --disable-ldap \
    --disable-manual \
    --with-ca-bundle=${PREFIX}/ssl/cacert.pem \
    --with-ssl=${PREFIX} \
    --with-zlib=${PREFIX} \
    --with-gssapi=${PREFIX} \
    --with-libssh2=${PREFIX} \
    --with-nghttp2=${PREFIX} \
|| cat config.log

make -j${CPU_COUNT} ${VERBOSE_AT}
# TODO :: test 1119... exit FAILED
# make test
make install

# Includes man pages and other miscellaneous.
rm -rf "${PREFIX}/share"
