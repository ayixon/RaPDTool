#!/usr/bin/perl

# The X Rendering Extension
package X11::Protocol::Ext::RENDER;

# Copyright (C) 2004 Stephen McCamant. All rights reserved. This program
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

    $x->{'ext_const'}{'PictType'} = ['Indexed', 'Direct'];
    $x->{'ext_const_num'}{'PictType'} =
      {make_num_hash($x->{'ext_const'}{'PictType'})};

    $x->{'ext_const'}{'PictOp'} =
      ['Clear', 'Src', 'Dst', 'Over', 'OverReverse', 'In', 'InReverse',
       'Out', 'OutReverse', 'Atop', 'AtopReverse', 'Xor', 'Add', 'Saturate',
       undef, undef,
       'DisjointClear', 'DisjointSrc', 'DisjointDst', 'DisjointOver',
       'DisjointOverReverse', 'DisjointIn', 'DisjointInReverse',
       'DisjointOut', 'DisjointOutReverse', 'DisjointAtop',
       'DisjointAtopReverse', 'DisjointXor',
       undef, undef, undef, undef,
       'ConjointClear', 'ConjointSrc', 'ConjointDst', 'ConjointOver',
       'ConjointOverReverse', 'ConjointIn', 'ConjointInReverse',
       'ConjointOut', 'ConjointOutReverse', 'ConjointAtop',
       'ConjointAtopReverse', 'ConjointXor'];
    $x->{'ext_const_num'}{'PictOp'} =
      {make_num_hash($x->{'ext_const'}{'PictOp'})};

    $x->{'ext_const'}{'SubPixel'} =
      ['Unknown', 'HorizontalRGB', 'HorizontalBGR', 'VerticalRGB',
       'VerticalBGR', 'None'];
    $x->{'ext_const_num'}{'SubPixel'} =
      {make_num_hash($x->{'ext_const'}{'SubPixel'})};

    $x->{'ext_const'}{'PolyEdge'} = ['Sharp', 'Smooth'];
    $x->{'ext_const_num'}{'PolyEdge'} =
      {make_num_hash($x->{'ext_const'}{'PolyEdge'})};

    $x->{'ext_const'}{'PolyMode'} = ['Precise', 'Imprecise'];
    $x->{'ext_const_num'}{'PolyMode'} =
      {make_num_hash($x->{'ext_const'}{'PolyMode'})};

    my @errors = ('PictFormat', 'Picture', 'PictOp', 'GlyphSet', 'Glyph');
    my @error_types = (1, 1, 1, 1, 1);
    my $err;
    for $err (@errors) {
	$x->{'ext_const'}{'Error'}[$error_num] = $err;
	$x->{'ext_error_type'}[$error_num] = shift @error_types;
	$error_num++;
    }
    $x->{'ext_const_num'}{'Error'} =
      {make_num_hash($x->{'ext_const'}{'Error'})};

    # Events: none

    my($Card16, $Int16, $Card8, $Int8);
    if (pack("L", 1) eq "\0\0\0\1") {
	$Int8 = "xxxc";
	$Card8 = "xxxC";
	$Int16 = "xxs";
	$Card16 = "xxS";
    } elsif (pack("L", 1) eq "\1\0\0\0") {
	$Int8 = "cxxx";
	$Card8 = "Cxxx";
	$Int16 = "sxx";
	$Card16 = "Sxx";
    } else {
	croak "Can't determine byte order!\n";
    }

    my @Attributes_ValueMask =
      (['repeat', sub { pack($Card8, $_[1]) }],
#       ['fill_nearest', sub { pack($Card8, $_[1]) }],
       ['alpha_map', sub { $_[1] = 0 if $_[1] eq "None"; pack("L", $_[1]) }],
       ['alpha_x_origin', sub { pack($Int16, $_[1]) }],
       ['alpha_y_origin', sub { pack($Int16, $_[1]) }],
       ['clip_x_origin', sub { pack($Int16, $_[1]) }],
       ['clip_y_origin', sub { pack($Int16, $_[1]) }],
       ['clip_mask', sub { $_[1] = 0 if $_[1] eq "None"; pack("L", $_[1]) }],
       ['graphics_exposures', sub { pack($Card8, $_[1]) }],
       ['subwindow_mode', sub {
	    $_[1] = $_[0]->num('GCSubwindowMode', $_[1]);
	    pack($Card8, $_[1]);
	}],
       ['poly_edge', sub {
	    $_[1] = $_[0]->num('PolyEdge', $_[1]);
	    pack($Card8, $_[1]);
	}],
       ['poly_mode', sub {
	    $_[1] = $_[0]->num('PolyMode', $_[1]);
	    pack($Card8, $_[1]);
	}],
       ['dither', sub { $_[1] = 0 if $_[1] eq "None"; pack("L", $_[1]) }],
       ['component_alpha', sub { pack($Card8, $_[1]) }],
      );

    # Requests
    $x->{'ext_request'}{$request_num} = 
      [
       ["RenderQueryVersion", sub {
	    my $self = shift;
	    return pack("LL", 0, 8); # We suport version 0.8
	}, sub {
	    my $self = shift;
	    my($data) = @_;
	    my($major, $minor) = unpack("xxxxxxxxLLxxxxxxxxxxxxxxx",
					$data);
	    return ($major, $minor);
	}],
       ["RenderQueryPictFormats", sub {
	    my $self = shift;
	    return "";
	}, sub {
	    my $self = shift;
	    my($data) = @_;
	    my($num_formats, $num_screens, $num_depths, $num_visuals,
	       $num_subpixel) = unpack("xxxxxxxxLLLLLxxxx",
				       substr($data, 0, 32));
	    my(@formats, @screens, @subpixels);
	    my $index = 32;
	    for (0 .. $num_formats - 1) {
		push @formats, [unpack("LCCxxSSSSSSSSL",
				      substr($data, $index, 28))];
		$formats[$#formats][1] =
		  $self->interp('PictType', $formats[$#formats][1]);
		$index += 28;
	    }
	    for (0 .. $num_screens - 1) {
		my($ndepths, $fallback) =
		  unpack("LL", substr($data, $index, 8));
		$index += 8;
		my @depths;
		for (0 .. $ndepths - 1) {
		    my($depth, $nvisuals) =
		      unpack("CxSxxxx", substr($data, $index, 8));
		    $index += 8;
		    my @visuals;
		    for (0 .. $nvisuals - 1) {
			my($visual, $format) =
			  unpack("LL", substr($data, $index, 8));
			$index += 8;
			push @visuals, [$visual, $format];
		    }
		    push @depths, [$depth, @visuals];
		}
		push @screens, [$fallback, @depths];
	    }
	    for (0 .. $num_subpixel - 1) {
		my $sp = unpack("L", substr($data, $index, 4));
		$index += 4;
		$sp = $self->interp('SubPixel', $sp);
		push @subpixels, $sp;
	    }
	    return ([@formats], [@screens], [@subpixels]);
	}],
       ["RenderQueryPictIndexValues", sub {
	    my $self = shift;
	    my($format) = @_;
	    return pack("L", $format);
	}, sub {
	    my($self) = shift;
	    my($data) = @_;
	    my($num_vals) = unpack("xxxxxxxxLxxxxxxxxxxxxxxxxxxxx",
				   substr($data, 0, 32));
	    my @values;
	    for my $index (0 .. $num_vals - 1) {
		my($pixel, $r, $g, $b, $alpha) =\
		  unpack("LSSSS", substr($data, 32 + 12*$index, 12));
		push @values, [$index, $r, $g, $b, $alpha];
	    }
	    return @values;
	}],
       ["RenderQueryDithers", sub {
	    die "RenderQueryDithers is unspecified";
	}, sub {
	    die "RenderQueryDithers is unspecified";
	}],
       ["RenderCreatePicture", sub {
	    my $self = shift;
	    my($pid, $drawable, $format, %values) = @_;
	    my($mask, $i, @values);
	    for $i (0 .. 12) {
		if (exists $values{$Attributes_ValueMask[$i][0]}) {
		    $mask |= (1 << $i);
		    push @values, 
		      &{$Attributes_ValueMask[$i][1]}
			($self, $values{$Attributes_ValueMask[$i][0]});
		}
	    }
	    return pack("LLLL", $pid, $drawable, $format, $mask)
	      . join("", @values);
	}],
       ["RenderChangePicture", sub {
	    my $self = shift;
	    my($pid, %values) = @_;
	    my($mask, $i, @values);
	    for $i (0 .. 12) {
		if (exists $values{$Attributes_ValueMask[$i][0]}) {
		    $mask |= (1 << $i);
		    push @values, 
		      &{$Attributes_ValueMask[$i][1]}
			($self, $values{$Attributes_ValueMask[$i][0]});
		}
	    }
	    return pack("LL", $pid, $mask) . join("", @values);
	}],
       ["RenderSetPictureClipRectangles", sub {
	    my $self = shift;
	    my($picture, $x_origin, $y_origin, @rects) = @_;
	    my $r;
	    for $r (@rects) {
		$r = pack("ssSS", @$r);
	    }
	    return pack("Lss", $picture, $x_origin, $y_origin)
	      . join("", @rects);
	}],
       ["RenderFreePicture", sub {
	    my $self = shift;
	    my($picture) = @_;
	    return pack("L", $picture);
	}],
       ["RenderComposite", sub {
	    my $self = shift;
	    my($op, $src, $mask, $dst, $src_x, $src_y, $mask_x, $mask_y,
	       $dst_x, $dst_y, $width, $height) = @_;
	    $op = $self->num('PictOp', $op);
	    $mask = 0 if $mask eq "None";
	    return pack("CxxxLLLssssssSS", $op, $src, $mask, $dst,
			$src_x, $src_y, $mask_x, $mask_y,
			$dst_x, $dst_y, $width, $height);
	}],
       ["RenderScale", sub {
	    die "RenderScale is unspecified";
	}],
       ["RenderTrapezoids", sub {
	    my $self = shift;
	    my($op, $src, $src_x, $src_y, $dst, $mask_format, @traps) = @_;
	    $op = $self->num('PictOp', $op);
	    $mask_format = 0 if $mask_format eq "None";
	    my $trap;
	    for $trap (@traps) {
		my($top, $bottom, $lx1, $ly1, $lx2, $ly2,
		   $rx1, $ry1, $rx2, $ry2) = @$trap;
		$top *= 2**16; $bottom *= 2**16;
		$lx1 *= 2**16; $ly1 *= 2**16;
		$lx2 *= 2**16; $ly2 *= 2**16;
		$rx1 *= 2**16; $ry1 *= 2**16;
		$rx2 *= 2**16; $ry2 *= 2**16;
		$trap = pack("llllllllll", $top, $bottom,
			     $lx1, $ly1, $lx2, $ly2,
			     $rx1, $ry1, $rx2, $ry2);
	    }
	    return pack("CxxxLLLss", $op, $src, $dst, $mask_format,
			$src_x, $src_y) . join("", @traps);
	}],
       ["RenderTriangles", sub {
	    my $self = shift;
	    my($op, $src, $src_x, $src_y, $dst, $mask_format, @tris) = @_;
	    $op = $self->num('PictOp', $op);
	    $mask_format = 0 if $mask_format eq "None";
	    my $tri;
	    for $tri (@tris) {
		my($x1, $y1, $x2, $y2, $x3, $y3) = @$tri;
		$x1 *= 2**16; $y1 *= 2**16;
		$x2 *= 2**16; $y2 *= 2**16;
		$x3 *= 2**16; $y3 *= 2**16;
		$tri = pack("llllll", $x1, $y1, $x2, $y2, $x3, $y3);
	    }
	    return pack("CxxxLLLss", $op, $src, $dst, $mask_format,
			$src_x, $src_y) . join("", @tris);
	}],
       ["RenderTriStrip", sub {
	    my $self = shift;
	    my($op, $src, $src_x, $src_y, $dst, $mask_format, @points) = @_;
	    $op = $self->num('PictOp', $op);
	    $mask_format = 0 if $mask_format eq "None";
	    my $pt;
	    for $pt (@points) {
		my($x, $y) = @$pt;
		$x *= 2**16; $y *= 2**16;
		$pt = pack("ll", $x, $y);
	    }
	    return pack("CxxxLLLss", $op, $src, $dst, $mask_format,
			$src_x, $src_y) . join("", @points);
	}],
       ["RenderTriFan", sub {
	    my $self = shift;
	    my($op, $src, $src_x, $src_y, $dst, $mask_format, @points) = @_;
	    $op = $self->num('PictOp', $op);
	    $mask_format = 0 if $mask_format eq "None";
	    my $pt;
	    for $pt (@points) {
		my($x, $y) = @$pt;
		$x *= 2**16; $y *= 2**16;
		$pt = pack("ll", $x, $y);
	    }
	    return pack("CxxxLLLss", $op, $src, $dst, $mask_format,
			$src_x, $src_y) . join("", @points);
	}],
       ["RenderColorTrapezoids", sub {
	    die "RenderColorTrapezoids is unimplemented";
	    # Also unimplemented in the XFree86 server, BTW.
	}],
       ["RenderColorTriangles", sub {
	    # N.B. This is not implemented in XFree86 yet, so it will
	    # always give a BadImplementation error.
	    my $self = shift;
	    my($op, $dst, @color_tris) = @_;
	    $op = $self->num('PictOp', $op);
	    my $ct;
	    for $ct (@color_tris) {
		my($x1, $y1, $r1, $g1, $b1, $a1,
		   $x2, $y2, $r2, $g2, $b2, $a2,
		   $x3, $y3, $r3, $g3, $b3, $a3) = @$ct;
		$x1 *= 2**16; $y1 *= 2**16;
		$x2 *= 2**16; $y2 *= 2**16;
		$x3 *= 2**16; $y3 *= 2**16;
		$ct = pack("llSSSS llSSSS llSSSS",
			   $x1, $y1, $r1, $g1, $b1, $a1,
			   $x2, $y2, $r2, $g2, $b2, $a2,
			   $x3, $y3, $r3, $g3, $b3, $a3);
	    }
	    return pack("CxxxL", $op, $dst) . join("", @color_tris);
	}],
       ["RenderTransform", sub {
	    die "RenderTransform is unspecified " .
	      "(did you mean RenderSetPictureTransform?)";
	}],
       ["RenderCreateGlyphSet", sub {
	    my $self = shift;
	    my($gsid, $format) = @_;
	    return pack("LL", $gsid, $format);
	}],
       ["RenderReferenceGlyphSet", sub {
	    my $self = shift;
	    my($new, $existing) = @_;
	    return pack("LL", $new, $existing);
	}],
       ["RenderFreeGlyphSet", sub {
	    my $self = shift;
	    my($gsid) = @_;
	    return pack("L", $gsid);
	}],
       ["RenderAddGlyphs", sub {
	    my $self = shift;
	    my($gsid, @glyphs) = @_;
	    my $g;
	    my(@gids, @infos, @datas);
	    for $g (@glyphs) {
		my($id, $width, $height, $x, $y, $x_off, $y_off, $data) = @$g;
		push @gids, $id;
		push @infos, pack("SSssss", $width, $height, $x, $y,
				  $x_off, $y_off);
		push @datas, pack(padded($data), $data);
	    }
	    return pack("LLL*", $gsid, scalar @glyphs, @gids)
	      . join("", @infos) . join("", @datas);
	}],
       ["RenderAddGlyphsFromPicture", sub {
	    die "RenderAddGlyphsFromPicture is unimplemented";
	    # And the specification is broken, since it doesn't say
	    # which glyphs you're adding!
	}],
       ["RenderFreeGlyphs", sub {
	    my $self = shift;
	    my($gsid, @glyphs) = @_;
	    return pack("LL*", $gsid, @glyphs);
	}],
       ["RenderCompositeGlyphs8", sub {
	    my $self = shift;
	    my($op, $src, $dst, $mask_format, $glyphable, $src_x, $src_y,
	       @items) = @_;
	    $op = $self->num('PictOp', $op);
	    $mask_format = 0 if $mask_format eq "None";
	    my $it;
	    for $it (@items) {
		if (ref($it) eq "ARRAY") {
		    my($dx, $dy, $str) = @$it;
		    $it = pack("Cxxxss".padded($str), length($str),
			       $dx, $dy, $str);
		} else {
		    $it = pack("CxxxxxxxL", 255, $it);
		}
	    }
	    return pack("CxxxLLLLss", $op, $src, $dst, $mask_format,
			$glyphable, $src_x, $src_y) . join("", @items);
	}],
       ["RenderCompositeGlyphs16", sub {
	    my $self = shift;
	    my($op, $src, $dst, $mask_format, $glyphable, $src_x, $src_y,
	       @items) = @_;
	    $op = $self->num('PictOp', $op);
	    $mask_format = 0 if $mask_format eq "None";
	    my $it;
	    for $it (@items) {
		if (ref($it) eq "ARRAY") {
		    my($dx, $dy, $str) = @$it;
		    $it = pack("Cxxxss".padded($str), length($str)/2,
			       $dx, $dy, $str);
		} else {
		    $it = pack("CxxxxxxxL", 255, $it);
		}
	    }
	    return pack("CxxxLLLLss", $op, $src, $dst, $mask_format,
			$glyphable, $src_x, $src_y) . join("", @items);
	}],
       ["RenderCompositeGlyphs32", sub {
	    my $self = shift;
	    my($op, $src, $dst, $mask_format, $glyphable, $src_x, $src_y,
	       @items) = @_;
	    $op = $self->num('PictOp', $op);
	    $mask_format = 0 if $mask_format eq "None";
	    my $it;
	    for $it (@items) {
		if (ref($it) eq "ARRAY") {
		    my($dx, $dy, $str) = @$it;
		    $it = pack("Cxxxss".padded($str), length($str)/4,
			       $dx, $dy, $str);
		} else {
		    $it = pack("CxxxxxxxL", 255, $it);
		}
	    }
	    return pack("CxxxLLLLss", $op, $src, $dst, $mask_format,
			$glyphable, $src_x, $src_y) . join("", @items);
	}],
       ["RenderFillRectangles", sub {
	    my $self = shift;
	    my($op, $dst, $color, @rects) = @_;
	    $op = $self->num('PictOp', $op);
	    $color = pack("SSSS", @$color);
	    my $r;
	    for $r (@rects) {
		$r = pack("ssSS", @$r);
	    }
	    return pack("CxxxL", $op, $dst) . $color . join("", @rects);
	}],
       ["RenderCreateCursor", sub {
	    my $self = shift;
	    my($cid, $src, $x, $y) = @_;
	    return pack("LLSS", $cid, $src, $x, $y);
	}],
       ["RenderSetPictureTransform", sub {
	    my $self = shift;
	    my($pict, @trans) = @_;
	    my $trans = pack("l9", map($_ * 2**16, @trans));
	    return pack("L", $pict) . $trans;
	}],
       ["RenderQueryFilters", sub {
	    my $self = shift;
	    my($drawable) = @_;
	    return pack("L", $drawable);
	}, sub {
	    my $self = shift;
	    my($data) = @_;
	    my(@aliases, @filters);
	    my($num_al, $num_filt) =
	      unpack("xxxxxxxxLLxxxxxxxxxxxxxxxx", substr($data, 0, 32));
	    my $index = 32;
	    for (0 .. $num_al - 1) {
		my $alias = unpack("S", substr($data, $index, 2));
		$index += 2;
		push @aliases, $alias;
	    }
	    $index += padding($index);
	    for (0 .. $num_filt) {
		my $len = unpack("C", substr($data, $index, 1));
		$index++;
		my $str = substr($data, $index, $len);
		$index += $len;
		push @filters, $str;
	    }
	    return ([@filters], [@aliases]);
	}],
       ["RenderSetPictureFilter", sub {
	    my $self = shift;
	    my($picture, $filter, @args) = @_;
	    return pack("LSxx".padded($filter)."L*", $picture, length($filter),
			$filter, map($_ * 2**16, @args));
	}],
       ["RenderCreateAnimCursor", sub {
	    my $self = shift;
	    my($cid, @frames) = @_;
	    my $fr;
	    for $fr (@frames) {
		$fr = pack("LL", @$fr);
	    }
	    return pack("L", $cid) . join("", @frames);
	}],
      ];
    my($i);
    for $i (0 .. $#{$x->{'ext_request'}{$request_num}}) {
	$x->{'ext_request_num'}{$x->{'ext_request'}{$request_num}[$i][0]} =
	  [$request_num, $i];
    }
    ($self->{'major'}, $self->{'minor'})
      = $x->req('RenderQueryVersion', 0, 8);
    if ($self->{'major'} != 0) {
	carp "Wrong RENDER version ($self->{'major'} != 0)";
	return 0;
    }
    return bless $self, $pkg;
}

1;
__END__

=head1 NAME

X11::Protocol::Ext::RENDER - Perl module for the X Rendering Extension

=head1 SYNOPSIS

  use X11::Protocol;
  $x = X11::Protocol->new($ENV{'DISPLAY'});
  $x->init_extension('RENDER') or die;

=head1 DESCRIPTION

The RENDER extension adds a new set of drawing primitives which
effectively represent a replacement of the drawing routines in the
core protocol, redesigned based on the needs of more modern
clients. It adds long-desired features such as subpixel positioning,
alpha compositing, direct specification of colors, and multicolored or
animated cursors. On the other hand, it omits features that are no
longer commonly used: wide lines, arbitrary polygons (only triangles
and horizontally-aligned trapezoids are supported), ellipses, bitwise
rendering operations, and server-side fonts (in favor of "glyphs" that
are rendered on the client side and transmitted once).

As of this writing (early 2004), the specification and implementation
both have rough edges, but there are relatively few alternatives for
offloading fancy graphics processing to the server, as is necessary
over slow links or if the client is written in a slow
language. Another possibility you might consider is the 2D subset of
OpenGL, though it doesn't yet have an X11::Protocol-compatible
interface.

=head1 SYMBOLIC CONSTANTS

This extension adds the constant types 'PictType', 'PictOp',
'SubPixel', 'PolyEdge', and 'PolyMode', with values as defined in the
standard.

=head1 REQUESTS

This extension adds several requests, called as shown below:

  $x->RenderQueryVersion($major, $minor)
  =>
  ($major, $minor)

  $x->RenderQueryPictFormats()
  =>
  ([[$id, $type, $depth,
     $red, $red_m, $green, $green_m, $blue, $blue_m,
     $alpha, $alpha_m, $cmap], ...],
   [[$fallback, [$depth, [$visual, $format], ...], ...], ...],
   [$subpixel, ...])

  $x->RenderQueryPictIndexValues($pict_format)
  =>
  ([$index, $red, $green, $blue, $alpha], ...)

  $x->RenderQueryFilters($drawable)
  =>
  ([@filters], [@aliases])

  $x->RenderCreatePicture($picture, $drawable, $format,
                          'attribute' => $value, ...)

  $x->RenderChangePicture($picture, 'attribute' => $value, ...)

  $x->RenderSetPictureClipRectangles($pic, $x_origin, $y_origin,
                                     [$x, $y, $width, $height], ...)

  $x->RenderSetPictureTransform($pict, $m11, $m12, $m13,
                                       $m21, $m22, $m23,
                                       $m31, $m32, $m33);

  $x->RenderSetPictureFilter($pict, $filter, @args)

  $x->RenderComposite($op, $src, $mask, $dst, $src_x, $src_y,
                      $mask_x, $mask_y, $dst_x, $dst_y,
                      $width, $height)

  $x->RenderFillRectangles($op, $dst, [$red, $green, $blue, $alpha],
                           [$x, $y, $width, $height], ...)

  $x->RenderTrapezoids($op, $src, $src_x, $src_y, $dst, $mask_format,
                       [$top, $bottom, $lx1, $ly1, $lx2, $ly2,
                                       $rx1, $ry1, $rx2, $ry2] ,...)

  $x->RenderTriangles($op, $src, $src_x, $src_y, $dst, $mask_format,
                      [$x1, $y1, $x2, $y2, $x3, $y3])

  $x->RenderTriStrip($op, $src, $src_x, $src_y, $dst, $mask_format,
                      [$x, $y], [$x, $y], [$x, $y], [$x, $y], ...)

  $x->RenderTriFan($op, $src, $src_x, $src_y, $dst, $mask_format,
                   [$x, $y], [$x, $y], [$x, $y], [$x, $y], ...)

  $x->RenderCreateGlyphSet($gsid, $format)

  $x->RenderReferenceGlyphSet($gsid, $existing)

  $x->RenderFreeGlyphSet($gsid)

  $x->RenderAddGlyphs($gsid, [$glyph, $width, $height,
                              $x, $y, $x_off, $y_off, $data], ...)

Warning: with some server implementations (including XFree86 through 4.4)
passing more than one glyph to AddGlyphs can hang or crash the server.
So don't do that.

  $x->RenderFreeGylphs($gsid, @glyphs)

  $x->RenderCompositeGlyphs8($op, $src, $dst, $mask_format, $gsid,
                             $src_x, $src_y,
                             [$delta_x, $delta_y, $str], ...)

  $x->RenderCompositeGlyphs16($op, $src, $dst, $mask_format, $gsid,
                              $src_x, $src_y,
                              [$delta_x, $delta_y, $str], ...)

  $x->RenderCompositeGlyphs32($op, $src, $dst, $mask_format, $gsid,
                              $src_x, $src_y,
                              [$delta_x, $delta_y, $str], ...)

In these three requests, new GlyphSetIDs can also be interspersed with
the array references.

  $x->RenderCreateCursor($cid, $source, $hot_x, $hot_y)

  $x->RenderCreateAnimCursor($cid, [$cursor, $delay], ...)

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
I<The X Rendering Extension (XFree86 draft standard)>.

=cut



