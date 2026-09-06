#!/usr/bin/perl

package X11::Auth;

# Copyright (C) 1997, 1999, 2005 Stephen McCamant. All rights
# reserved. This program is free software; you can redistribute and/or
# modify it under the same terms as Perl itself.

use Carp;
use strict;
use vars '$VERSION';
use FileHandle;
require 5.000;

$VERSION = 0.05;

sub new {
    my($class, $fname) = @_;
    $fname = $fname || $main::ENV{"XAUTHORITY"} ||
	"$main::ENV{HOME}/.Xauthority";
    return 0 unless -e $fname;
    my $self = bless {}, $class;
    $self->{filename} = $fname;
    my($fh) = new FileHandle;
    $fh->open("<$fname") or croak "Can't open $fname: $!";
    $self->{filehandle} = $fh;
    return $self;
}

sub open { new(@_) }

sub read {
    my($self, $len) = @_;
    my($buf);
    my $ret = read $self->{filehandle}, $buf, $len;
    if (not defined $ret) {
	croak "Can't read authority file " . $self->{filename} . ": $!";
    } elsif ($ret < $len) {
	warn "Expecting $len bytes, got $ret at " . tell($self->{filename});
	croak "Unexpected short read from authority file" . $self->{filename};
    }
    return $buf;
}

sub get_one {
    my $self = shift;
    my(@a, $x);
    my $warned_nulls = 0;
  RETRY: {
	if ($self->{filehandle}->eof) {
	    close $self->{filehandle};
	    return ();
	}
	$x = unpack("n", $self->read(2)); # Family
	my $type = {256 => 'Local', 65535 => 'Wild', 254 => 'Netname',
		    253 => 'Krb5Principal', 252 => 'LocalHost',
		    0 => 'Internet', 1 => 'DECnet', 2 => 'Chaos',
		    5 => 'ServerInterpreted', 6 => 'InternetV6'}->{$x};
	if (not defined($type)) {
	    warn "Error in $self->{filename}: unknown address type $x";
	}
	push @a, $type;
	
	$x = unpack("n", $self->read(2)); # Address
	push @a, $self->read($x);
	
	$x = unpack("n", $self->read(2)); # Display `number'
	push @a, $self->read($x);
	
	$x = unpack("n", $self->read(2)); # Authorization name
	push @a, $self->read($x);
	
	$x = unpack("n", $self->read(2)); # Authorization data
	push @a, $self->read($x);

	if ($type eq "Internet" and $a[1] eq "" and $a[2] eq ""
	    and $a[3] eq "" and $a[4] eq "") {
	    warn "Error in $self->{filename}: unexpected null bytes"
	      unless $warned_nulls;
	    $warned_nulls = 1;
	    @a = ();
	    next RETRY;
	}

	return @a;
    }
}

sub get_all {
    my $self = shift;
    return @{$self->{data}} if $self->{data};
    my(@a, @x);
    while (@x = $self->get_one) {
	push @a, [@x];
    }
    $self->{data} = [@a];
    return @a;
}

sub get_by_host {
    my $self = shift;
    my($host, $fam, $dpy) = @_;
    if ($host eq "localhost" or $host eq "127.0.0.1") {
	require Sys::Hostname;
	$host = Sys::Hostname::hostname();
    }
    my($addr);
    $addr = gethostbyname($host) if $fam eq "Internet";
    #print "host $host, addr $addr\n";
    my($d);
    for $d ($self->get_all) {
	next unless $dpy eq $d->[2];
	next unless $fam eq $d->[0] or ($fam eq "Internet"
					and $d->[0] eq "Local");
	if ($fam eq "Internet" or $fam eq "Local") {
	    if ($addr && $d->[1] eq $addr or $d->[1] eq $host) {
		return ($d->[3], $d->[4]);
	    }
	}
    }
    return ();
}

1;

__END__

=head1 NAME

X11::Auth - Perl module to read X11 authority files

=head1 SYNOPSIS

  require X11::Auth;
  $a = new X11::Auth;
  ($auth_type, $auth_data) = $a->get_by_host($host, $disp_num);

=head1 DESCRIPTION

This module is an approximate perl replacement for the libXau C library
and the xauth(1) program. It reads and interprets the files (usually
'~/.Xauthority') that hold authorization data used in connecting to
X servers. Since it was written mainly for the use of X11::Protocol,
its functionality is currently restricted to reading, not writing, of
these files.

=head1 METHODS

=head2 new

  $auth = X11::Auth->new;
  $auth = X11::Auth->open($filename);

Open an authority file, and create an object to handle it. The filename
will be taken from the XAUTHORITY environment variable, if present, or
'.Xauthority' in the user's home directory, or it may be overridden by
an argument. 'open' may be used as a synonym.

=head2 get_one

  ($family, $host_addr, $display_num, $auth_name, $auth_data)
     = $auth->get_one;

Read one entry from the file. Returns a null list at end of file.
$family is usually 'Internet' or 'Local', and $display_num can
be any string.

=head2 get_all

  @auth_data = $auth->get_all;

Read all of the entries in the file. Each member of the array returned
is an array ref similar to the list returned by get_one().

=head2 get_by_host

  ($auth_name, $auth_data)
     = $auth->get_by_host($host, $family, $display_num);

Get authentication data for a connection of type $family to display
$display_num on $host. If $family is 'Internet', the host will be
translated into an appropriate address by gethostbyname(). If no data
is found, returns an empty list.

=head1 COMPATIBILITY

The following table shows the (rough) correspondence between libXau
calls and X11::Auth methods:

  libXau                     X11::Auth
  ------                     ---------
  XauFileName                $ENV{XAUTHORITY}
                             || "$ENV{HOME}/.Xauthority"
  fopen(XauFileName(), "rb") $auth = new X11::Auth
  XauReadAuth                $auth->get_one
  XauWriteAuth
  XauGetAuthByAddr           $auth->get_by_host
  XauGetBestAuthByAddr 
  XauLockAuth
  XauUnlockAuth
  XauDisposeAuth

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>

=head1 SEE ALSO

L<perl(1)>, L<X11::Protocol>, L<Xau(3)>, L<xauth(1)>,
lib/Xau/README in the X11 source distribution.

=cut
