#!/usr/bin/perl

package X11::Protocol::Connection::FileHandle;

# Copyright (C) 1997, 2003 Stephen McCamant. All rights reserved. This
# program is free software; you can redistribute and/or modify it
# under the same terms as Perl itself.

use FileHandle;
use Carp;
use strict;
use vars '$VERSION', '@ISA';

use X11::Protocol::Connection;
@ISA = ('X11::Protocol::Connection');

$VERSION = 0.02;

sub give {
    my($self) = shift;
    my($msg) = @_;
    my($fh) = $$self;
    $fh->print($msg) or croak $!;
}

sub get {
    my($self) = shift;
    my($len) = @_;
    my($x, $n, $o) = ("", 0, 0);
    my($fh) = $$self;
    until ($o == $len) {
	$n = sysread $fh, $x, $len - $o, $o;
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
    my($fh) = $$self;
}

1;
__END__

=head1 NAME

X11::Protocol::Connection::FileHandle - Perl module base class for FileHandle-based X11 connections

=head1 SYNOPSIS

  package X11::Protocol::Connection::WeirdFH;
  use X11::Protocol::Connection::FileHandle;
  @ISA = ('X11::Protocol::Connection::FileHandle')

=head1 DESCRIPTION

This module defines get(), give() and fh() methods common to
X11::Protocol::Connection types that are based on the FileHandle
package. They expect the object they are called with to be a reference
to a FileHandle.

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
L<X11::Protocol::Connection::INETFH>,
L<X11::Protocol::Connection::UNIXFH>,
L<FileHandle>.

=cut


