

set -ex



touch checksum.txt
openssl sha256 checksum.txt
openssl ecparam -name prime256v1
python -c "from six.moves import urllib; urllib.request.urlopen('https://pypi.org')"
exit 0
