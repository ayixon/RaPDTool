# perl_openssl.pm - debhelper addon for running dh_perl_openssl
#
# Copyright 2010, Ansgar Burchardt <ansgar@debian.org>
# Copyright 2016, Niko Tyni <ntyni@debian.org>
#
# This program is free software, you can redistribute it and/or modify it
# under the same terms as Perl itself.

use warnings;
use strict;

use Debian::Debhelper::Dh_Lib;

insert_after("dh_perl", "dh_perl_openssl");

1;
