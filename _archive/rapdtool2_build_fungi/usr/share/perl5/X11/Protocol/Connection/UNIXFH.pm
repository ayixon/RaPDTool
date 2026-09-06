#!/usr/bin/perl

package X11::Protocol::Connection::UNIXFH;

# Copyright (C) 1997 Stephen McCamant. All rights reserved. This program
# is free software; you can redistribute and/or modify it under the same
# terms as Perl itself.

use X11::Protocol::Connection::FileHandle;
use FileHandle;
use Socket;
use Carp;
use strict;
use vars qw($VERSION @ISA);

@ISA = ('X11::Protocol::Connection::FileHandle');

$VERSION = 0.01;

sub open {
    my($pkg) = shift;
    my($host, $dispnum) = @_;
    my($sock) = new FileHandle;
    socket $sock, PF_UNIX(), SOCK_STREAM(), 0 or croak "socket: $!";
    connect $sock, sockaddr_un("/tmp/.X11-unix/X$dispnum")
      or croak "Can't connect to display `unix:$dispnum': $!";
    $sock->autoflush(1);
    return bless \$sock, $pkg;
}
1;
__END__

=head1 NAME

X11::Protocol::Connection::UNIXFH - Perl module for FileHandle-based Unix-domain X11 connections

=head1 SYNOPSIS

  use X11::Protocol;
  use X11::Protocol::Connection::UNIXFH;
  $conn = X11::Protocol::Connection::UNIXFH
    ->open($host, $display_number);
  $x = X11::Protocol->new($conn); 

=head1 DESCRIPTION

This module is used by X11::Protocol to establish a connection and
communicate with a server over a local Unix-domain socket connection,
using the FileHandle module. The host argument is ignored.

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
L<X11::Protocol::Connection::INETFH>,
L<X11::Protocol::Connection::FileHandle>, 
L<FileHandle>.

=cut

