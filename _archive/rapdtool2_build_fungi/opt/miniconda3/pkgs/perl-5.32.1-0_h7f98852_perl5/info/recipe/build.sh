#!/bin/bash

if [[ "${build_platform}" == osx-64 && "${target_platform}" == osx-arm64 ]]; then
  archflags="-arch x86_64 -arch arm64"
  export MACOSX_DEPLOYMENT_TARGET=10.9
fi

if [[ "${target_platform}" == osx-* ]]; then
  if [[ "${target_platform}" == osx-64 ]]; then
    CFLAGS="${CFLAGS} -D_DARWIN_FEATURE_CLOCK_GETTIME=0"
  fi
  ccflags="${CFLAGS} -fno-common -DPERL_DARWIN -no-cpp-precomp -Werror=partial-availability -D_DARWIN_FEATURE_CLOCK_GETTIME=0 -fno-strict-aliasing -pipe -fstack-protector-strong -DPERL_USE_SAFE_PUTENV ${archflags} ${CPPFLAGS}"
elif [[ "${target_platform}" == linux-* ]]; then
  ccflags="${CFLAGS} -D_REENTRANT -D_GNU_SOURCE -fwrapv -fno-strict-aliasing -pipe -fstack-protector-strong -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_FORTIFY_SOURCE=2"
fi

# world-writable files are not allowed
chmod -R o-w "${SRC_DIR}"

declare -a _config_args

# Installation layout:
#  - prefix and vendor prefix are the same
#  - all scripts go in PREFIX/bin
#  - core/site/vendor package split adapted from Arch Linux
#  - non-(minor)-version specific files go in PREFIX/lib/perl5
#  - (minor) version specific files go in, e.g., PREFIX/lib/perl5/5.32

perl_lib=".../../lib/perl5"
perl_archlib="${perl_lib}/${PKG_VERSION%.*}"
perl_core=/core_perl
perl_site=/site_perl
perl_vendor=/vendor_perl

_config_args+=(
  "-Dprefix=${PREFIX}"
  "-Dvendorprefix=${PREFIX}"

  "-Dscriptdir=${PREFIX}/bin"
  "-Dsitescript=${PREFIX}/bin"
  "-Dvendorscript=${PREFIX}/bin"

  -Duserelocatableinc
  -Duseshrplib
  -Dinc_version_list=none

  "-Dprivlib=${perl_lib}${perl_core}"
  "-Dsitelib=${perl_lib}${perl_site}"
  "-Dvendorlib=${perl_lib}${perl_vendor}"

  "-Darchlib=${perl_archlib}${perl_core}"
  "-Dsitearch=${perl_archlib}${perl_site}"
  "-Dvendorarch=${perl_archlib}${perl_vendor}"
)

_config_args+=(-Dinstallusrbinperl=n)

_config_args+=(-Dusethreads)
_config_args+=(-Dcccdlflags="-fPIC")
_config_args+=(-Dldflags="${LDFLAGS} ${archflags}")
# .. ran into too many problems with '.' not being on @INC:
_config_args+=(-Ddefault_inc_excludes_dot=n)

if [[ -n "${ccflags}" ]]; then
  _config_args+=(-Dccflags="${ccflags}")
fi
if [[ -n "${GCC:-${CC}}" ]]; then
  _config_args+=("-Dcc=${GCC:-${CC}}")
fi
if [[ -n "${AR}" ]]; then
  _config_args+=("-Dar=${AR}")
fi
if [[ "${target_platform}" == linux-* ]]; then
  _config_args+=(-Dlddlflags="-shared ${LDFLAGS}")
# elif [[ "${target_platform}" == osx-* ]]; then
#   _config_args+=(-Dlddlflags=" -bundle -undefined dynamic_lookup ${LDFLAGS}")
fi
# -Dsysroot prevents Configure rummaging around in /usr and
# linking to system libraries (like GDBM, which is GPL). An
# alternative is to pass -Dusecrosscompile but that prevents
# all Configure/run checks which we also do not want.
_config_args+=("-Dsysroot=${CONDA_BUILD_SYSROOT}")

_config_args+=(
  -Dmyhostname=conda
  -Dmydomain=.conda
  -Dperladmin=conda
  -Dcf_by=conda
  -Dcf_email=conda
)

_config_args+=(
  "-Dsysman=${PREFIX}/man/man1"
  "-Dman1dir=.../../man/man1"
  "-Dman3dir=.../../man/man3"
)

./Configure -de "${_config_args[@]}"
make

# change permissions again after building
chmod -R o-w "${SRC_DIR}"

# Seems we hit:
# lib/perlbug .................................................... # Failed test 21 - [perl \#128020] long body lines are wrapped: maxlen 1157 at ../lib/perlbug.t line 154
# FAILED at test 21
# https://rt.perl.org/Public/Bug/Display.html?id=128020
# make test
make install

# Replace hard-coded BUILD_PREFIX by value from env as CC, CFLAGS etc need to be properly set to be usable by ExtUtils::MakeMaker module
pushd "${perl_archlib/...\/../${PREFIX}}${perl_core}"
patch -p1 < "${RECIPE_DIR}/dynamic_config.patch"
sed -i.bak "s|${BUILD_PREFIX}|\$compilerroot|g" Config_heavy.pl

sed -i.bak "s|${BUILD_PREFIX}|\$compilerroot|g" Config.pm
sed -i.bak "s|cc => '\(.*\)'|cc => \"\1\"|g" Config.pm
sed -i.bak "s|libpth => '\(.*\)'|libpth => \"\1\"|g" Config.pm

# 2 more seds for osx:
sed -i.bak "s|\\\c|\\\\\\\c|g" Config_heavy.pl
sed -i.bak "s|DPERL_SBRK_VIA_MALLOC \$ccflags|DPERL_SBRK_VIA_MALLOC \\\\\$ccflags|g" Config_heavy.pl

if [[ "${target_platform}" == osx-arm64 ]]; then
  sed -i.bak 's/-arch x86_64 -arch arm64//g' Config_heavy.pl
fi

rm -f {Config_heavy.pl,Config.pm}.{orig,bak}
popd

# Keep empty site/vendor directories, work around issue:
#  https://github.com/conda/conda-build/issues/1014
for path in {"${perl_lib}","${perl_archlib}"}{"${perl_site}","${perl_vendor}"} ; do
  path="${path/...\/../${PREFIX}}"
  mkdir -p "${path}"
  touch "${path}/.conda-build.keep"
done

# Add empty perllocal.pod to avoid Perl packages clobbering on that file.
# (If all recipes used ExtUtils::MakeMaker's NO_PERLLOCAL=1 this wouldn't be needed).
touch "${perl_archlib/...\/../${PREFIX}}${perl_core}"/perllocal.pod
