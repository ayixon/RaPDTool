

set -ex



unzip -h
zipinfo -h
test "$(strings $(which unzip) | grep -ci lchmod)" -eq 0
exit 0
