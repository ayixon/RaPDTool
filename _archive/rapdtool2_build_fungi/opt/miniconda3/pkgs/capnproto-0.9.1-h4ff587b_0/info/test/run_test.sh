

set -ex



capnp --help
capnpc --help
capnpc-c++ --help
capnpc-capnp --help
test -d "$PREFIX/include/capnp"
test -f "$PREFIX/lib/libcapnp${SHLIB_EXT}"
test -f "$PREFIX/lib/libcapnpc${SHLIB_EXT}"
test -f "$PREFIX/lib/libcapnp-rpc${SHLIB_EXT}"
test -f "$PREFIX/lib/libkj${SHLIB_EXT}"
test -f "$PREFIX/lib/libkj-async${SHLIB_EXT}"
exit 0
