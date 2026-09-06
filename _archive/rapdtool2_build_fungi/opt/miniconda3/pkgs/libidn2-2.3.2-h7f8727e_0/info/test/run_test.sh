

set -ex



test -f "${PREFIX}/include/idn2.h"
test -f "${PREFIX}/lib/libidn2${SHLIB_EXT}"
test ! -f "${PREFIX}/lib/libidn2.a"
exit 0
