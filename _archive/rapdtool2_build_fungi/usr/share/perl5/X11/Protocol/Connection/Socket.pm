#!/usr/bin/perl

package X11::Protocol::Connection::Socket;

# Copyright (C) 1997, 1999, 2003 Stephen McCamant. All rights
# reserved. This program is free software; you can redistribute and/or
# modify it under the same terms as Perl itself.

use IO::Socket;
use Carp;
use strict;
use vars '$VERSION', '@ISA';

use X11::Protocol::Connection;
@ISA = ('X11::Protocol::Connection');

$VERSION = 0.02;

sub give {
    my($self) = shift;
    my($msg) = @_;
    my($sock) = $$self;
    $sock->write($msg, length($msg)) or croak $!;
}

sub get {
    my($self) = shift;
    my($len) = @_;
    my($x, $n, $o) = ("", 0, 0);
    my($sock) = $$self;
    until ($o == $len) {
	$n = $sock->sysread($x, $len - $o, $o);
	croak $! unless defined $n;
	$o += $n;
    }
    return $x;
}

sub fh {
    my($self) = shift;
    return $$self;
}

sub flush {
    my($self) = shift;
    my($sock) = $$self;
    $sock->flush;
}

1;
__END__

=head1 NAME

X11::Protocol::Connection::Socket - Perl module base class for IO::Socket-based X11 connections

=head1 SYNOPSIS

  package X11::Protocol::Connection::WeirdSocket;
  use X11::Protocol::Connection::Socket;
  @ISA = ('X11::Protocol::Connection::Socket')

=head1 DESCRIPTION

This module defines get(), give() and fh() methods common to
X11::Protocol::Connection types that are based on IO::Socket. They
expect the object they are called with to be a reference to an
IO::Socket.

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
L<X11::Protocol::Connection::INETSocket>,
L<X11::Protocol::Connection::UNIXSocket>, 
L<IO::Socket>.

=cut






