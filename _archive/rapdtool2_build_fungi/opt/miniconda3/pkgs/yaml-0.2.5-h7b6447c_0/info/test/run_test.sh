

set -ex



test -f "${PREFIX}/include/yaml.h"
test -f "${PREFIX}/lib/libyaml${SHLIB_EXT}"
exit 0
