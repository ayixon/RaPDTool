#!/usr/bin/perl

package X11::Protocol::Ext::BIG_REQUESTS; # The `Big Requests Extension'

# Copyright (C) 1997 Stephen McCamant. All rights reserved. This program
# is free software; you can redistribute and/or modify it under the same
# terms as Perl itself.

# The actual mechanism for packing large requests is in X11::Protocol --
# it just checks whether $x->{'ext'}{'BIG_REQUESTS'} is defined.
# The only thing this module does is issue the BigReqEnable request.

use X11::Protocol qw(pad padding padded make_num_hash);
use Carp;

use strict;
use vars '$VERSION';

$VERSION = 0.01;

sub new {
    my($pkg, $x, $request_num, $event_num, $error_num) = @_;
    my($self) = {};

    # Constants

    # Events

    # Requests
    $x->{'ext_request'}{$request_num} = 
      [
       ["BigReqEnable", sub {
	    my($self) = shift;
	    return "";
	}, sub {
	    my($self) = shift;
	    my($data) = @_;
	    my($max_len) = unpack("xxxxxxxxIxxxxxxxxxxxxxxxxxxxx", $data);
	    return ($max_len);
	}]
      ];
    my($i);
    for $i (0 .. $#{$x->{'ext_request'}{$request_num}}) {
	$x->{'ext_request_num'}{$x->{'ext_request'}{$request_num}[$i][0]} =
	  [$request_num, $i];
    }
    $x->{'maximum_request_length'} = $x->req('BigReqEnable');
    return bless $self, $pkg;
}

1;
__END__

=head1 NAME

X11::Protocol::Ext::BIG_REQUESTS - Perl module for the X11 protocol Big Requests extension

=head1 SYNOPSIS

  use X11::Protocol;
  $x = X11::Protocol->new($ENV{'DISPLAY'});
  $x->init_extension('BIG_REQUESTS') or die;

=head1 DESCRIPTION

This module is used by the X11::Protocol module to participate in
the 'Big Requests' extension to the X protocol. Once initialized, it
transparently allows requests of more than 262140 (65535 * 4) bytes.
The new maximum request length is available as
C<$x-E<gt>maximum_request_length>.

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
I<Big Requests Extension (X Consortium Standard)>.

=cut
