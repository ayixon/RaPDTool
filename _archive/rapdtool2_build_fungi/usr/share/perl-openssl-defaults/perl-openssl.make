# find out the ABI version for generating a perl-openssl-abi-* dependency.
# See #848113.
PERL_OPENSSL_ABI_VERSION=$(shell /usr/share/perl-openssl-defaults/get-libssl-abi)
