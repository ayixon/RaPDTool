#!/usr/bin/perl

package X11::Protocol::Connection;

# Copyright (C) 1997 Stephen McCamant. All rights reserved. This program
# is free software; you can redistribute and/or modify it under the same
# terms as Perl itself.

use Carp;
use strict;
use vars '$VERSION';

$VERSION = 0.01;

sub give {
    croak "X11 connection object doesn't support output";
}

sub get {
    croak "X11 connection object doesn't support input";
}

sub fh {
    croak "X11 connection object is incompatible with perl filehandles";
}

sub open {
    croak "X11 connection object can't open itself";
}

1;
__END__

=head1 NAME

X11::Protocol::Connection - Perl module abstract base class for X11 client to server connections

=head1 SYNOPSIS

  # In connection object module
  package X11::Protocol::Connection::CarrierPigeon;
  use X11::Protocol::Connection;
  @ISA = ('X11::Protocol::Connection');
  sub open { ... }
  sub give { ... }
  sub get { ... }
  sub fh { ... }
  ...

  # In program
  $connection = X11::Protocol::Connection::CarrierPigeon
    ->open($host, $display_number);
  $x = X11::Protocol->new($connection);

  $connection->give($data);

  $reply = unpack("I", $connection->get(4));

  use IO::Select;
  $sel = IO::select->new($connection->fh);
  if ($sel->can_read == $connection->fh) ...

=head1 DESCRIPTION

This module is an abstract base class for the various
X11::Protocol::Connection::* modules that provide connections to X
servers for the X11::Protocol module. It provides stubs for the
following methods:

=head2 open

  $conn = X11::Protocol::Connection::Foo->open($host, $display_num)

Open a connection to the specified display (numbered from 0) on the
specified $host.

=head2 give

  $conn->give($data)

Send the given data to the server. Normally, this method is used only
by the protocol module itself.

=head2 get

  $data = $conn->get($n)

Read $n bytes of data from the server. Normally, this method is used
only by the protocol module itself.

=head2 fh

  $filehandle = $conn->fh

Return an object suitable for use as a filehandle. This is mainly
useful for doing select() and other such system calls.

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
L<X11::Protocol::Connection::Socket>,
L<X11::Protocol::Connection::FileHandle>,
L<X11::Protocol::Connection::INETSocket>,
L<X11::Protocol::Connection::UNIXSocket>,
L<X11::Protocol::Connection::INETFH>,
L<X11::Protocol::Connection::UNIXFH>.

=cut
