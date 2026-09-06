

set -ex



perl --help
perl -V:cf_by | grep -qF "'conda'"
perl -V:cf_email | grep -qF "'conda'"
perl -V:perladmin | grep -qF "'conda'"
perl -e 'print "$_\n" for @INC' | grep -qxF "${PREFIX}/lib/perl5/site_perl"
perl -e 'print "$_\n" for @INC' | grep -qxF "${PREFIX}/lib/perl5/vendor_perl"
perl -e 'print "$_\n" for @INC' | grep -qxF "${PREFIX}/lib/perl5/core_perl"
perl -e 'print "$_\n" for @INC' | grep -qxF "${PREFIX}/lib/perl5/5.32/site_perl"
perl -e 'print "$_\n" for @INC' | grep -qxF "${PREFIX}/lib/perl5/5.32/vendor_perl"
perl -e 'print "$_\n" for @INC' | grep -qxF "${PREFIX}/lib/perl5/5.32/core_perl"

exit 0
