#!/usr/bin/perl

# The `X11 Nonrectangular Window Shape Extension'
package X11::Protocol::Ext::SHAPE; 

# Copyright (C) 1997 Stephen McCamant. All rights reserved. This program
# is free software; you can redistribute and/or modify it under the same
# terms as Perl itself.

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

    $x->{'ext_const'}{'ShapeKind'} = ['Bounding', 'Clip'];
    $x->{'ext_const_num'}{'ShapeKind'} =
      {make_num_hash($x->{'ext_const'}{'ShapeKind'})};

    $x->{'ext_const'}{'ShapeOp'} = ['Set', 'Union', 'Intersect', 'Subtract',
				    'Invert'];
    $x->{'ext_const_num'}{'ShapeOp'} =
      {make_num_hash($x->{'ext_const'}{'ShapeOp'})};

    # Events
    $x->{'ext_const'}{'Events'}[$event_num] = "ShapeNotify";
    $x->{'ext_events'}[$event_num] =
      ["xCxxLssSSLCxxxxxxxxxxx", ['shape_kind', 'ShapeKind'], 'x', 'y',
       'width', 'height', 'time', 'shaped'];

    # Requests
    $x->{'ext_request'}{$request_num} = 
      [
       ["ShapeQueryVersion", sub {
	    my($self) = shift;
	    return "";
	}, sub {
	    my($self) = shift;
	    my($data) = @_;
	    my($major, $minor) = unpack("xxxxxxxxSSxxxxxxxxxxxxxxxxxxxx",
					$data);
	    return ($major, $minor);
	}],
       ["ShapeRectangles", sub {
	    my($self) = shift;
	    my($dest, $kind, $op, $x, $y, $ordering, @rects) = @_;
	    $op = $self->num('ShapeOp', $op);
	    $kind = $self->num('ShapeKind', $kind);
	    $ordering = $self->num('ClipRectangleOrdering', $ordering);
	    my($r);
	    for $r (@rects) {
		$r = pack("ssSS", @$r);
	    }
	    return pack("CCCxLss", $op, $kind, $ordering, $dest, $x, $y)
	      . join("", @rects);
	}],
       ["ShapeMask", sub {
	    my($self) = shift;
	    my($win, $kind, $op, $x, $y, $pixmap) = @_;
	    $op = $self->num('ShapeOp', $op);
	    $kind = $self->num('ShapeKind', $kind);
	    $pixmap = 0 if $pixmap eq "None";
	    return pack("CCxxLssL", $op, $kind, $win, $x, $y, $pixmap);
	}],
       ["ShapeCombine", sub {
	    my($self) = shift;
	    my($dst, $d_kind, $op, $x, $y, $src, $s_kind) = @_;
	    $op = $self->num('ShapeOp', $op);
	    $d_kind = $self->num('ShapeKind', $d_kind);
	    $s_kind = $self->num('ShapeKind', $s_kind);
	    return pack("CCCxLssL", $op, $d_kind, $s_kind, $dst, $x, $y, $src);
	}],
       ["ShapeOffset", sub {
	    my($self) = shift;
	    my($win, $kind, $x, $y) = @_;
	    $kind = $self->num('ShapeKind', $kind);
	    return pack("CxxxLss", $kind, $win, $x, $y);
	}],
       ["ShapeQueryExtents", sub {
	    my($self) = shift;
	    my($win) = @_;
	    return pack("L", $win);
	}, sub {
	    my($self) = shift;
	    my($data) = @_;
	    my($b, $c, $b_x, $b_y, $b_w, $b_h, $c_x, $c_y, $c_w, $c_h)
	      = unpack("xxxxxxxxCCxxssSSssSSxxxx", $data);
	    return ($b, $c, $b_x, $b_y, $b_w, $b_h, $c_x, $c_y, $c_w, $c_h);
	}],
       ["ShapeSelectInput", sub {
	    my($self) = shift;
	    my($win, $enable) = @_;
	    return pack("LCxxx", $win, $enable);
	}],
       # The R6 documentation gets the next two minor opcodes wrong;
       # this usage follows <X11/extensions/shape.h>.
       ["ShapeInputSelected", sub {
	    my($self) = shift;
	    my($win) = @_;
	    return pack("L", $win);
	}, sub {
	    my($self) = shift;
	    my($data) = @_;
	    return unpack("xCxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", $data);
	}],
       ["ShapeGetRectangles", sub {
	    my($self) = shift;
	    my($win, $kind) = @_;
	    $kind = $self->num('ShapeKind', $kind);
	    return pack("LCxxx", $win, $kind);
	}, sub {
	    my($self) = shift;
	    my($data) = @_;
	    my($ordering, $nrects) =
	      unpack("xCxxxxxxLxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32));
	    my($i, @rects);
	    for $i (0 .. $nrects - 1) {
		push @rects, [unpack("ssSS", substr($data, 32 + 8 * $i, 8))];
	    }
	    return ($self->interp('ClipRectangleOrdering', $ordering), @rects);
	}]
      ];
    my($i);
    for $i (0 .. $#{$x->{'ext_request'}{$request_num}}) {
	$x->{'ext_request_num'}{$x->{'ext_request'}{$request_num}[$i][0]} =
	  [$request_num, $i];
    }
    ($self->{'major'}, $self->{'minor'}) = $x->req('ShapeQueryVersion');
    if ($self->{'major'} != 1) {
	carp "Wrong SHAPE version ($self->{'major'} != 1)";
	return 0;
    }
    return bless $self, $pkg;
}

1;
__END__

=head1 NAME

X11::Protocol::Ext::SHAPE - Perl module for the X11 Protocol Nonrectangular Window Shape Extension

=head1 SYNOPSIS

  use X11::Protocol;
  $x = X11::Protocol->new($ENV{'DISPLAY'});
  $x->init_extension('SHAPE') or die;

=head1 DESCRIPTION

This module is used by the X11::Protocol module to participate in the
shaped window extension to the X protocol, allowing windows to be of any
shape, not just rectangles.

=head1 SYMBOLIC CONSTANTS

This extension adds the constant types 'ShapeKind' and 'ShapeOp', with values
as defined in the standard.

=head1 EVENTS

This extension adds the event type 'ShapeNotify', with values as specified in
the standard. This event is selected using the ShapeSelectInput() request.

=head1 REQUESTS

This extension adds several requests, called as shown below:

  $x->ShapeQueryVersion
  =>
  ($major, $minor)

  $x->ShapeRectangles($dest, $destKind, $op, $xOff, $yOff,
		      $ordering, @rectangles) 

  $x->ShapeMask($dest, $destKind, $op, $xOff, $yOff, $source)

  $x->ShapeCombine($dest, $destKind, $op, $xOff, $yOff, $source,
		   $sourceKind)

  $x->ShapeOffset($dest, $destKind, $xOff, $yOff)

  $x->ShapeQueryExtents($dest)
  =>
  ($boundingShaped, $clipShaped,
   ($xBoundingShape, $yBoundingShape,
    $widthBoundingShape, $heightBoundingShape)  
   ($xClipShape, $yClipShape, $widthClipShape, $heightClipShape))

  $x->ShapeSelectInput($window, $enable)  

  $x->ShapeInputSelected($window)
  =>
  $enable

  $x->ShapeGetRectangles($window, $kind)
  =>
  ($ordering, [$x, $y, $width, $height], ...)

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>, 
L<X11::Protocol>,
I<Nonrectangular Window Shape Extension (X Consortium Standard)>.

=cut



