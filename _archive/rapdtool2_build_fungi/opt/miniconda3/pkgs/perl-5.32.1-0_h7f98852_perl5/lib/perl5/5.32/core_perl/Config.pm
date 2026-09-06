# This file was created by configpm when Perl was built. Any changes
# made to this file will be lost the next time perl is built.

# for a description of the variables, please have a look at the
# Glossary file, as written in the Porting folder, or use the url:
# https://github.com/Perl/perl5/blob/blead/Porting/Glossary

package Config;
use strict;
use warnings;
our ( %Config, $VERSION );

$VERSION = "5.032001";

# Skip @Config::EXPORT because it only contains %Config, which we special
# case below as it's not a function. @Config::EXPORT won't change in the
# lifetime of Perl 5.
my %Export_Cache = (myconfig => 1, config_sh => 1, config_vars => 1,
		    config_re => 1, compile_date => 1, local_patches => 1,
		    bincompat_options => 1, non_bincompat_options => 1,
		    header_files => 1);

@Config::EXPORT = qw(%Config);
@Config::EXPORT_OK = keys %Export_Cache;

# Need to stub all the functions to make code such as print Config::config_sh
# keep working

sub bincompat_options;
sub compile_date;
sub config_re;
sub config_sh;
sub config_vars;
sub header_files;
sub local_patches;
sub myconfig;
sub non_bincompat_options;

# Define our own import method to avoid pulling in the full Exporter:
sub import {
    shift;
    @_ = @Config::EXPORT unless @_;

    my @funcs = grep $_ ne '%Config', @_;
    my $export_Config = @funcs < @_ ? 1 : 0;

    no strict 'refs';
    my $callpkg = caller(0);
    foreach my $func (@funcs) {
	die qq{"$func" is not exported by the Config module\n}
	    unless $Export_Cache{$func};
	*{$callpkg.'::'.$func} = \&{$func};
    }

    *{"$callpkg\::Config"} = \%Config if $export_Config;
    return;
}

die "$0: Perl lib version (5.32.1) doesn't match executable '$^X' version ($])"
    unless $^V;

$^V eq 5.32.1
    or die sprintf "%s: Perl lib version (5.32.1) doesn't match executable '$^X' version (%vd)", $0, $^V;


sub relocate_inc {
  my $libdir = shift;
  return $libdir unless $libdir =~ s!^\.\.\./!!;
  my $prefix = $^X;
  if ($prefix =~ s!/[^/]*$!!) {
    while ($libdir =~ m!^\.\./!) {
      # Loop while $libdir starts "../" and $prefix still has a trailing
      # directory
      last unless $prefix =~ s!/([^/]+)$!!;
      # but bail out if the directory we picked off the end of $prefix is .
      # or ..
      if ($1 eq '.' or $1 eq '..') {
	# Undo! This should be rare, hence code it this way rather than a
	# check each time before the s!!! above.
	$prefix = "$prefix/$1";
	last;
      }
      # Remove that leading ../ and loop again
      substr ($libdir, 0, 3, '');
    }
    $libdir = "$prefix/$libdir";
  }
  $libdir;
}

sub FETCH {
    my($self, $key) = @_;

    # check for cached value (which may be undef so we use exists not defined)
    return exists $self->{$key} ? $self->{$key} : $self->fetch_string($key);
}

sub TIEHASH {
    bless $_[1], $_[0];
}

sub DESTROY { }

sub AUTOLOAD {
    require 'Config_heavy.pl';
    goto \&launcher unless $Config::AUTOLOAD =~ /launcher$/;
    die "&Config::AUTOLOAD failed on $Config::AUTOLOAD";
}

use File::Basename;
my $compilerroot = "";
if (length $ENV{'CC'}) {
  $compilerroot = dirname($ENV{'CC'})."/../";
}
elsif (length $ENV{'PREFIX'}) {
  $compilerroot = $ENV{'PREFIX'}."/";
}
elsif (length $ENV{'_'}) {
  $compilerroot = dirname($ENV{'_'})."/../";
}

# tie returns the object, so the value returned to require will be true.
tie %Config, 'Config', {
    archlibexp => relocate_inc('.../../lib/perl5/5.32/core_perl'),
    archname => 'x86_64-linux-thread-multi',
    cc => "$compilerroot/bin/x86_64-conda-linux-gnu-gcc",
    d_readlink => 'define',
    d_symlink => 'define',
    dlext => 'so',
    dlsrc => 'dl_dlopen.xs',
    dont_use_nlink => undef,
    exe_ext => '',
    inc_version_list => ' ',
    intsize => '4',
    ldlibpthname => 'LD_LIBRARY_PATH',
    libpth => "$compilerroot/bin/../lib/gcc/x86_64-conda-linux-gnu/9.3.0/lib $compilerroot/bin/../lib/gcc/x86_64-conda-linux-gnu/9.3.0/include-fixed $compilerroot/x86_64-conda-linux-gnu/sysroot/usr/lib $compilerroot/x86_64-conda-linux-gnu/sysroot/lib $compilerroot/x86_64-conda-linux-gnu/sysroot/lib64 $compilerroot/x86_64-conda-linux-gnu/sysroot/usr/lib64",
    osname => 'linux',
    osvers => '4.15.0-1113-azure',
    path_sep => ':',
    privlibexp => relocate_inc('.../../lib/perl5/core_perl'),
    scriptdir => '/home/conda/feedstock_root/build_artifacts/perl_1622804860086/_h_env_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placehold_placeh/bin',
    sitearchexp => relocate_inc('.../../lib/perl5/5.32/site_perl'),
    sitelibexp => relocate_inc('.../../lib/perl5/site_perl'),
    so => 'so',
    useithreads => 'define',
    usevendorprefix => 'define',
    version => '5.32.1',
};
