#!/usr/bin/perl

# The XC-MISC Extension
package X11::Protocol::Ext::XC_MISC;

# This module was originally written in 1998 by Jay Kominek.  As of
# February 10th, 2003, he has placed it in the public domain.

use X11::Protocol qw(pad padding padded make_num_hash);
use Carp;

use strict;
use vars '$VERSION';

$VERSION = 0.01;

sub new
{
    my($pkg, $x, $request_num, $event_num, $error_num) = @_;
    my($self) = {};

    # Constants

    # Events

    # Requests
    $x->{'ext_request'}{$request_num} =
	[
	 ["XCMiscGetVersion", sub {
	     my($self) = shift;
	     my($major, $minor) = @_;
	     return pack("SS", $major, $minor);
	 }, sub {
	     my($self) = shift;
	     my($data) = @_;
	     my($major,$minor)
	       = unpack("xxxxxxxxSSxxxxxxxxxxxxxxxxxxxx",$data);
	     return($major,$minor);
	 }],
	 ["XCMiscGetXIDRange", sub {
	     my($self) = shift;
	     return "";
	 }, sub {
	     my($self) = shift;
	     my($data) = @_;
	     my($start_id,$count) = unpack("xxxxxxxxLLxxxxxxxxxxxxxxxx",$data);
	     return($start_id,$count);
	 }],
	 ["XCMiscGetXIDList", sub {
	     my($self) = shift;
	     return pack("L",shift);
	 }, sub {
	     my($self) = shift;
	     my($data) = @_;
	     my($count,@ids) = unpack("xxxxxxxxLxxxxxxxxxxxxxxxxxxxxL*",$data);
	     return($count,@ids);
	 }]
	 ];
    my($i);
    for $i (0 .. $#{$x->{'ext_request'}{$request_num}}) {
	$x->{'ext_request_num'}{$x->{'ext_request'}{$request_num}[$i][0]} =
	    [$request_num, $i];
    }
    ($self->{'major'},$self->{'minor'}) = $x->req('XCMiscGetVersion', 1, 1);
    if ($self->{'major'} != 1) {
	carp "Wrong XC-MISC version ($self->{'major'} != 1)";
	return undef;
    }
    return bless $self, $pkg;
}

1;
__END__

=head1 NAME

X11::Protocol::Ext::XC_MISC - Perl module for the X11 Protocol XC-MISC Extension

=head1 SYNOPSIS

  use X11::Protocol;
  $x = X11::Protocol->new();
  $x->init_extension('XC-MISC');

=head1 DESCRIPTION

This module is used by the programmer to pre-acquire large numbers of
X resource IDs to be used with the X11::Protocol module.

If supported by the server, X11::Protocol will load this module
automatically when additional resource IDs are needed via the standard
new_rsrc() interface.  However, if you anticipate that a program will
run for a long time and allocate many resources, it would be a good
idea to initialize the extension at startup to verify its existence.

=head1 REQUESTS

This extension adds three requests, called as shown below:

  $x->XCMiscGetVersion => ($major, $minor)

  $x->XCMiscGetXIDRange => ($start_id, $count)

  $x->XCMiscGetXIDList($count) => ($count, @ids)

=head1 AUTHOR

Jay Kominek <jay.kominek@colorado.edu>.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
I<XC-MISC Extension (X Consortium Standard)>.
