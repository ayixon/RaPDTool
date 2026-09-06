require '_h2ph_pre.ph';

no warnings qw(redefine misc);

unless(defined(&__always_inline)) {
    eval 'sub __always_inline () { &__inline__;}' unless defined(&__always_inline);
}
1;
