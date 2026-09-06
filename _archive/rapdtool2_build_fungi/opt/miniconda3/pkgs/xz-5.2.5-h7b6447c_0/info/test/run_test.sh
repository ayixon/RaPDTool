

set -ex



xz --help
unxz --help
lzma --help
conda inspect linkages -p $PREFIX $PKG_NAME
exit 0
