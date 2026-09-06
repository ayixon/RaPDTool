#!/usr/bin/perl

package X11::Protocol::Connection::INETSocket;

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

our $SOCKET_CLASS;

$SOCKET_CLASS
    = ((eval { require IO::Socket::IP })
       ? "IO::Socket::IP"
       : do { require IO::Socket::INET; "IO::Socket::INET"; })
    unless (defined ($SOCKET_CLASS));

sub open {
    my($pkg) = shift;
    my($host, $dispnum) = @_;
    my($sock) = $SOCKET_CLASS->new   ('PeerAddr' => $host,
				      'PeerPort' => 6000 + $dispnum,
				      'Type' => SOCK_STREAM(),
				      'Proto' => "tcp");
    croak "Can't connect to display `$host:$dispnum': $!" unless $sock;
    $sock->autoflush(1);
    return bless \$sock, $pkg;
}
1;
__END__

=head1 NAME

X11::Protocol::Connection::INETSocket - Perl module for IO::Socket::INET-based X11 connections

=head1 SYNOPSIS

  use X11::Protocol;
  use X11::Protocol::Connection::INETSocket;
  $conn = X11::Protocol::Connection::INETSocket
    ->open($host, $display_number);
  $x = X11::Protocol->new($conn); 

=head1 DESCRIPTION

This module is used by X11::Protocol to establish a connection and communicate
with a server over a TCP/IP connection, using the IO::Socket::INET module.

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
L<X11::Protocol::Connection::Socket>,
L<X11::Protocol::Connection::UNIXSocket>, 
L<IO::Socket>.

=cut


