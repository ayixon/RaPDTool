#!/usr/bin/perl

package X11::Protocol::Connection::UNIXSocket;

# Copyright (C) 1997 Stephen McCamant. All rights reserved. This program
# is free software; you can redistribute and/or modify it under the same
# terms as Perl itself.

use X11::Protocol::Connection::Socket;
use IO::Socket;
use Socket;
use Carp;
use strict;
use vars qw($VERSION @ISA);

@ISA = ('X11::Protocol::Connection::Socket');

$VERSION = 0.01;

sub open {
    my($pkg) = shift;
    my($host, $dispnum) = @_;
    my($sock) = IO::Socket::UNIX->new('Type' => SOCK_STREAM(),
				      'Peer' => "/tmp/.X11-unix/X$dispnum");
    croak "Can't connect to display `unix:$dispnum': $!" unless $sock;
    $sock->autoflush(0);
    return bless \$sock, $pkg;
}
1;
__END__

=head1 NAME

X11::Protocol::Connection::UNIXSocket - Perl module for IO::Socket::UNIX-based X11 connections

=head1 SYNOPSIS

  use X11::Protocol;
  use X11::Protocol::Connection::UNIXSocket;
  $conn = X11::Protocol::Connection::UNIXSocket
    ->open($host, $display_number);
  $x = X11::Protocol->new($conn); 

=head1 DESCRIPTION

This module is used by X11::Protocol to establish a connection and
communicate with a server over a local Unix-domain socket connection,
using the IO::Socket::UNIX module. The host argument is ignored.

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
L<X11::Protocol::Connection::INETSocket>,
L<X11::Protocol::Connection::Socket>, 
L<IO::Socket>.

=cut


