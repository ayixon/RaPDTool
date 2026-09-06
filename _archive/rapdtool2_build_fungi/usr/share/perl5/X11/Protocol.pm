#!/usr/bin/perl

package X11::Protocol;

# Copyright (C) 1997-2000, 2003-2006 Stephen McCamant. All rights
# reserved. This program is free software; you can redistribute and/or
# modify it under the same terms as Perl itself.

use Carp;
use strict;
use vars qw($VERSION $AUTOLOAD @ISA @EXPORT_OK);
require Exporter;

@ISA = ('Exporter');

@EXPORT_OK = qw(pad padding padded hexi make_num_hash default_error_handler);

$VERSION = "0.56";

sub padding ($) {
    my($x) = @_;
    -$x & 3;
}

sub pad ($)  {
    my($x) = @_;
    padding(length($x));
}

sub padded ($) {
    my $l = length($_[0]);
    "a" . $l . "x" x (-$l & 3);
}

sub hexi ($) {
    "0x" . sprintf("%x", $_[0]);
}


length(pack("L", 0)) == 4 or croak "can't happen";

my($Byte_Order, $Card16, $Int16, $Card8, $Int8);

if (pack("L", 1) eq "\0\0\0\1") {
    $Byte_Order = 'B';
    $Int8 = "xxxc";
    $Card8 = "xxxC";
    $Int16 = "xxs";
    $Card16 = "xxS";
} elsif (pack("L", 1) eq "\1\0\0\0") {
    $Byte_Order = 'l';
    $Int8 = "cxxx";
    $Card8 = "Cxxx";
    $Int16 = "sxx";
    $Card16 = "Sxx";
} else {
    croak "Can't determine byte order!\n";
}

my($Default_Display);

if ($^O eq "MSWin32") {
    $Default_Display = "localhost";
} else {
    $Default_Display = "unix";
}

sub give {
    my($self) = shift;
    $self->{'connection'}->give(@_);
}

sub get {
    my($self) = shift;
    return $self->{'connection'}->get(@_);
}

sub flush {
    my $self = shift;
    $self->{'connection'}->flush();
}

my(%Const) = 
    (
     'VisualClass' => ['StaticGray', 'GrayScale', 'StaticColor', 
		       'PseudoColor', 'TrueColor', 'DirectColor'],
     'BitGravity' => ['Forget', 'Static', 'NorthWest', 'North',
		      'NorthEast', 'West', 'Center', 'East',
		      'SouthWest', 'South', 'SouthEast'],
     'WinGravity' => ['Unmap', 'Static', 'NorthWest', 'North',
		      'NorthEast', 'West', 'Center', 'East', 'SouthWest',
		      'South', 'SouthEast'],
     'EventMask' => ['KeyPress', 'KeyRelease', 'ButtonPress', 'ButtonRelease',
		     'EnterWindow', 'LeaveWindow', 'PointerMotion',
		     'PointerMotionHint', 'Button1Motion', 'Button2Motion',
		     'Button3Motion', 'Button4Motion', 'Button5Motion',
		     'ButtonMotion', 'KeymapState', 'Exposure',
		     'VisibilityChange', 'StructureNotify', 'ResizeRedirect',
		     'SubstructureNotify', 'SubstructureRedirect',
		     'FocusChange', 'PropertyChange', 'ColormapChange',
		     'OwnerGrabButton'],
     'Events' => [0, 0, 'KeyPress' , 'KeyRelease', 'ButtonPress',
		  'ButtonRelease', 'MotionNotify', 'EnterNotify',
		  'LeaveNotify', 'FocusIn', 'FocusOut', 'KeymapNotify',
		  'Expose', 'GraphicsExposure', 'NoExposure',
		  'VisibilityNotify', 'CreateNotify', 'DestroyNotify',
		  'UnmapNotify', 'MapNotify', 'MapRequest',
		  'ReparentNotify', 'ConfigureNotify', 'ConfigureRequest',
		  'GravityNotify', 'ResizeRequest', 'CirculateNotify',
		  'CirculateRequest', 'PropertyNotify', 'SelectionClear',
		  'SelectionRequest', 'SelectionNotify',
		  'ColormapNotify', 'ClientMessage', 'MappingNotify'],
     'PointerEvent' => [0, 0, 'ButtonPress', 'ButtonRelease', 
			'EnterWindow', 'LeaveWindow', 'PointerMotion',
			'PointerMotionHint', 'Button1Motion',
			'Button2Motion', 'Button3Motion', 'Button4Motion',
			'Button5Motion', 'ButtonMotion', 'KeymapState'],
     'DeviceEvent' => ['KeyPress', 'KeyRelease', 'ButtonPress',
		       'ButtonRelease', 0, 0, 'PointerMotion',
		       'PointerMotionHint', 'Button1Motion', 
		       'Button2Motion', 'Button3Motion', 'Button4Motion',
		       'Button5Motion', 'ButtonMotion'],
     'KeyMask' => ['Shift', 'Lock', 'Control', 'Mod1', 'Mod2', 'Mod3',
		   'Mod4', 'Mod5'],
     'Significance' => ['LeastSignificant', 'MostSignificant'],
     'BackingStore' => ['Never', 'WhenMapped', 'Always'],
     'Bool' => ['False', 'True'],
     'Class' => ['CopyFromParent', 'InputOutput', 'InputOnly'],
     'MapState' => ['Unmapped', 'Unviewable', 'Viewable'],
     'StackMode' => ['Above', 'Below', 'TopIf', 'BottomIf', 'Opposite'],
     'CirculateDirection' => ['RaiseLowest', 'LowerHighest'],
     'ChangePropertyMode' => ['Replace', 'Prepend', 'Append'],
     'CrossingNotifyDetail' => ['Ancestor', 'Virtual', 'Inferior',
				'Nonlinear', 'NonlinearVirtual'],
     'CrossingNotifyMode' => ['Normal', 'Grab', 'Ungrab'],
     'FocusDetail' => ['Ancestor', 'Virtual', 'Inferior', 'Nonlinear',
		       'NonlinearVirtual', 'Pointer', 'PointerRoot',
		       'None'],
     'FocusMode' => ['Normal', 'Grab', 'Ungrab', 'WhileGrabbed'],
     'VisibilityState' => ['Unobscured', 'PartiallyObscured',
			   'FullyObscured'],
     'CirculatePlace' => ['Top', 'Bottom'],
     'PropertyNotifyState' => ['NewValue', 'Deleted'],
     'ColormapNotifyState' => ['Uninstalled', 'Installed'],
     'MappingNotifyRequest' => ['Modifier', 'Keyboard', 'Pointer'],
     'SyncMode' => ['Synchronous', 'Asynchronous'],
     'GrabStatus' => ['Success', 'AlreadyGrabbed', 'InvalidTime',
		      'NotViewable', 'Frozen'],
     'AllowEventsMode' => ['AsyncPointer', 'SyncPointer', 'ReplayPointer',
			   'AsyncKeyboard', 'SyncKeyboard',
				'ReplayKeyboard', 'AsyncBoth', 'SyncBoth'],
     'InputFocusRevertTo' => ['None', 'PointerRoot', 'Parent'],
     'DrawDirection' => ['LeftToRight', 'RightToLeft'],
     'ClipRectangleOrdering' => ['UnSorted', 'YSorted', 'YXSorted',
				 'YXBanded'],
     'CoordinateMode' => ['Origin', 'Previous'],
     'PolyShape' => ['Complex', 'Nonconvex', 'Convex'],
     'ImageFormat' => ['Bitmap', 'XYPixmap', 'ZPixmap'],
     'SizeClass' => ['Cursor', 'Tile', 'Stipple'],
     'LedMode' => ['Off', 'On'],
     'AutoRepeatMode' => ['Off', 'On', 'Default'],
     'ScreenSaver' => ['No', 'Yes', 'Default'],
     'HostChangeMode' => ['Insert', 'Delete'],
     'HostFamily' => ['Internet', 'DECnet', 'Chaos', 0, 0,
		      'ServerInterpreted', 'InternetV6'],
     'AccessMode' => ['Disabled', 'Enabled'],
     'CloseDownMode' => ['Destroy', 'RetainPermanent', 'RetainTemporary'],
     'ScreenSaverAction' => ['Reset', 'Activate'],
     'MappingChangeStatus' => ['Success', 'Busy', 'Failed'],
     'GCFunction' => ['Clear', 'And', 'AndReverse', 'Copy',
		      'AndInverted', 'NoOp', 'Xor', 'Or', 'Nor', 'Equiv',
		      'Invert', 'OrReverse', 'CopyInverted', 'OrInverted',
		      'Nand', 'Set'],
     'GCLineStyle' => ['Solid', 'OnOffDash', 'DoubleDash'],
     'GCCapStyle' => ['NotLast', 'Butt', 'Round', 'Projecting'],
     'GCJoinStyle' => ['Miter', 'Round', 'Bevel'],
     'GCFillStyle' => ['Solid', 'Tiled', 'Stippled', 'OpaqueStippled'],
     'GCFillRule' => ['EvenOdd', 'Winding'],
     'GCSubwindowMode' => ['ClipByChildren', 'IncludeInferiors'],
     'GCArcMode' => ['Chord', 'PieSlice'],
     'Error' => [0, 'Request', 'Value', 'Window', 'Pixmap', 'Atom',
		 'Cursor', 'Font', 'Match', 'Drawable', 'Access', 'Alloc',
		 'Colormap', 'GContext', 'IDChoice', 'Name', 'Length',
		 'Implementation'],
     );

my(%Const_num) = (); # Filled in dynamically

sub interp {
    my($self) = shift;
    return $_[1] unless $self->{'do_interp'};
    return $self->do_interp(@_);
}

sub do_interp {
    my $self = shift;
    my($type, $num) = @_;
    carp "Unknown constant type `$type'\n"
	unless exists $self->{'const'}{$type}
         or exists $self->{'ext_const'}{$type};
    return $num if $num < 0;
    return $self->{'const'}{$type}[$num] || $self->{'ext_const'}{$type}[$num];
}

sub make_num_hash {
    my($from) = @_;
    my(%hash);
    @hash{@$from} = (0 .. $#{$from});
    return %hash;
}

sub num ($$) {
    my($self) = shift;
    my($type, $x) = @_;
    carp "Unknown constant type `$type'\n"
	unless exists $self->{'const'}{$type}
          or exists $self->{'ext_const'}{$type};
    $self->{'const_num'}{$type} = {make_num_hash($self->{'const'}{$type})}
	unless exists $self->{'const_num'}{$type};
    if (exists $self->{'const_num'}{$type}{$x}) {
	return $self->{'const_num'}{$type}{$x};
    } elsif (exists $self->{'ext_const_num'}{$type}{$x}) {
	return $self->{'ext_const_num'}{$type}{$x};
    } else {
	return $x;
    }
}

my(@Attributes_ValueMask) = 
  (["background_pixmap", sub {$_[1] = 0 if $_[1] eq "None";
			      $_[1] = 1 if $_[1] eq "ParentRelative";
			      pack "L", $_[1];}],
   ["background_pixel", sub {pack "L", $_[1];}],
   ["border_pixmap", sub {$_[1] = 0 if $_[1] eq "CopyFromParent";
			  pack "L", $_[1];}],
   ["border_pixel", sub {pack "L", $_[1];}], 
   ["bit_gravity", sub {$_[1] = $_[0]->num('BitGravity', $_[1]);
			pack $Card8, $_[1];}],
   ["win_gravity", sub {$_[1] = $_[0]->num('WinGravity', $_[1]);
			pack $Card8, $_[1];}],
   ["backing_store", sub {$_[1] = 0 if $_[1] eq "NotUseful";
			  $_[1] = 1 if $_[1] eq "WhenMapped";
			  $_[1] = 2 if $_[1] eq "Always";
			  pack $Card8, $_[1];}],
   ["backing_planes", sub {pack "L", $_[1];}],
   ["backing_pixel", sub {pack "L", $_[1];}],
   ["override_redirect", sub {pack $Card8, $_[1];}],
   ["save_under", sub {pack $Card8, $_[1];}],
   ["event_mask", sub {pack "L", $_[1];}],
   ["do_not_propagate_mask", sub {pack "L", $_[1];}],
   ["colormap", sub {$_[1] = 0 if $_[1] eq "CopyFromParent";
		     pack "L", $_[1];}],
   ["cursor", sub {$_[1] = 0 if $_[1] eq "None";
		   pack "L", $_[1];}]);

my(@Configure_ValueMask) =
  (["x", sub {pack $Int16, $_[1];}],
   ["y", sub {pack $Int16, $_[1];}],
   ["width", sub {pack $Card16, $_[1];}],
   ["height", sub {pack $Card16, $_[1];}],
   ["border_width", sub {pack $Card16, $_[1];}],
   ["sibling", sub {pack "L", $_[1];}],
   ["stack_mode", sub {$_[1] = $_[0]->num('StackMode', $_[1]);
		       pack $Card8, $_[1];}]);

my(@GC_ValueMask) =
  (['function', sub {
	$_[1] = $_[0]->num('GCFunction', $_[1]);
	$_[1] = pack($Card8, $_[1]);
    }, sub {}],
     ['plane_mask', sub {$_[1] = pack("L", $_[1]);}, sub {}],
     ['foreground', sub {$_[1] = pack("L", $_[1]);}, sub {}],
     ['background', sub {$_[1] = pack("L", $_[1]);}, sub {}],
     ['line_width', sub {$_[1] = pack($Card16, $_[1]);}, sub {}],
     ['line_style', sub {
	 $_[1] = $_[0]->num('GCLineStyle', $_[1]);
	 $_[1] = pack($Card8, $_[1]);
     }, sub {}],
     ['cap_style', sub {
	 $_[1] = $_[0]->num('GCCapStyle', $_[1]);
	 $_[1] = pack($Card8, $_[1]);
     }, sub {}],
     ['join_style', sub {
	 $_[1] = $_[0]->num('GCJoinStyle', $_[1]);
	 $_[1] = pack($Card8, $_[1]);
     }, sub {}],
     ['fill_style', sub {
	 $_[1] = $_[0]->num('GCFillStyle', $_[1]);
	 $_[1] = pack($Card8, $_[1]);
     }, sub {}],
     ['fill_rule', sub {
	 $_[1] = $_[0]->num('GCFillRule', $_[1]);
	 $_[1] = pack($Card8, $_[1]);
     }, sub {}],
     ['tile', sub {$_[1] = pack("L", $_[1]);}, sub {}],
     ['stipple', sub {$_[1] = pack("L", $_[1]);}, sub {}],
     ['tile_stipple_x_origin', sub {$_[1] = pack($Int16, $_[1]);}, sub {}],
     ['tile_stipple_y_origin', sub {$_[1] = pack($Int16, $_[1]);}, sub {}],
     ['font', sub {$_[1] = pack("L", $_[1]);}, sub {}],
     ['subwindow_mode', sub {
	 $_[1] = $_[0]->num('GCSubwindowMode', $_[1]);
	 $_[1] = pack($Card8, $_[1]);
     }, sub {}],
     ['graphics_exposures', sub {$_[1] = pack($Card8, $_[1]);}, sub {}],
     ['clip_x_origin', sub {$_[1] = pack($Int16, $_[1]);}, sub {}],
     ['clip_y_origin', sub {$_[1] = pack($Int16, $_[1]);}, sub {}],
     ['clip_mask', sub {
	 $_[1] = 0 if $_[1] eq "None";
	 $_[1] = pack("L", $_[1]);
     }, sub {}],
     ['dash_offset', sub {$_[1] = pack($Card16, $_[1]);}, sub {}],
     ['dashes', sub {$_[1] = pack($Card8, $_[1]);}, sub {}],
     ['arc_mode', sub {
	 $_[1] = $_[0]->num('GCArcMode', $_[1]);
	 $_[1] = pack($Card8, $_[1]);
     }, sub {}]);

my(@KeyboardControl_ValueMask) = 
    (['key_click_percent', sub {$_[1] = pack($Int8, $_[1]);}],
     ['bell_percent', sub {$_[1] = pack($Int8, $_[1]);}],
     ['bell_pitch', sub {$_[1] = pack($Int16, $_[1])}],
     ['bell_duration', sub {$_[1] = pack($Int16, $_[1])}],
     ['led', sub {$_[1] = pack($Card8, $_[1])}],
     ['led_mode', sub {$_[1] = $_[0]->num('LedMode', $_[1]);
		       $_[1] = pack($Card8, $_[1]);}],
     ['key', sub {$_[1] = pack($Card8, $_[1]);}],
     ['auto_repeat_mode', sub {$_[1] = $_[0]->num('AutoRepeatMode', $_[1]);
			       $_[1] = pack($Card8, $_[1]);}]);

my(@Events) = 
    (0, 0,  
#   if ($code >= 2 and $code <= 5) # (Key|Button)(Press|Release)
     (["xCxxLLLLssssSCx", 'detail', 'time', 'root', 'event',
       ['child', ['None']], 'root_x', 'root_y', 'event_x', 'event_y',
       'state', 'same_screen']) x 4,
#    elsif ($code == 6) # MotionNotify
     ["xCxxLLLLssssSCx", ['detail', ['Normal', 'Hint']], 'time', 'root',
      'event', ['child', ['None']], 'root_x', 'root_y', 'event_x',
      'event_y', 'state', 'same_screen'],
#    elsif ($code == 7 or $code == 8) # (Enter|Leave)Notify
     (["xCxxLLLLssssSCC", ['detail', 'CrossingNotifyDetail'], 'time',
       'root', 'event', ['child', ['None']], 'root_x', 'root_y',
       'event_x', 'event_y', 'state', ['mode', 'CrossingNotifyMode'],
       [0, sub {$_[0]{'flags'} |= 1 if $_[0]{'focus'};
		$_[0]{'flags'} |= 2 if $_[0]{'same_screen'};}],
       'flags',
       [sub {$_[0]{'focus'} = $_[0]{'flags'} & 1;
	     $_[0]{'same_screen'} = (($_[0]{'flags'} & 2) != 0)}, 0]
       ]) x 2,
#    elsif ($code == 9 or $code == 10) # Focus(In|Out)
     (["xCxxLCxxxxxxxxxxxxxxxxxxxxxxx", ['detail', 'FocusDetail'], 'event',
       ['mode', 'FocusMode']]) x 2,
#    elsif ($code == 11) # KeymapNotify (weird)
     [sub {
	 my($self, $data, %h) = @_;
	 my($keys) = "\0" . substr($data, 1, 31);
	 $h{'keys'} = $keys;
	 delete $h{sequence_number};
	 return %h;
     }, sub {
	 my $self = shift;
	 my(%h) = @_;	 
	 my($data) = "\0" . substr($h{"keys"}, 1, 31);
	 return ($data, 0);
     }],
#    elsif ($code == 12) # Expose
    ["xxxxLSSSSSxxxxxxxxxxxxxx", 'window', 'x', 'y', 'width', 'height',
     'count'],
#    elsif ($code == 13) # GraphicsExposure
    ["xxxxLSSSSSSCxxxxxxxxxxx", 'drawable', 'x', 'y', 'width', 'height',
     'minor_opcode', 'count', 'major_opcode'],
#    elsif ($code == 14) # NoExposure
    ["xxxxLSCxxxxxxxxxxxxxxxxxxxxx", 'drawable', 'minor_opcode',
    'major_opcode'],
#    elsif ($code == 15) # VisibilityNotify
    ["xxxxLCxxxxxxxxxxxxxxxxxxxxxxx", 'window', ['state', 'VisibilityState']],
#    elsif ($code == 16) # CreateNotify
    ["xxxxLLssSSSCxxxxxxxxx", 'parent', 'window', 'x', 'y', 'width',
    'height', 'border_width', 'override_redirect'],
#    elsif ($code == 17) # DestroyNotify
    ["xxxxLLxxxxxxxxxxxxxxxxxxxx", 'event', 'window'],
#    elsif ($code == 18) # UnmapNotify
    ["xxxxLLCxxxxxxxxxxxxxxxxxxx", 'event', 'window', 'from_configure'],
#    elsif ($code == 19) # MapNotify
    ["xxxxLLCxxxxxxxxxxxxxxxxxxx", 'event', 'window', 'override_redirect'],
#    elsif ($code == 20) # MapRequest
    ["xxxxLLxxxxxxxxxxxxxxxxxxxx", 'parent', 'window'],
#    elsif ($code == 21) # ReparentNotify
    ["xxxxLLLssCxxxxxxxxxxx", 'event', 'window', 'parent', 'x', 'y',
    'override_redirect'],
#    elsif ($code == 22) # ConfigureNotify
    ["xxxxLLLssSSSCxxxxx", 'event', 'window', 'above_sibling', 'x', 'y',
    'width', 'height', 'border_width', 'override_redirect'],
#    elsif ($code == 23) # ConfigureRequest
    ["xCxxLLLssSSSSxxxx", ['stack_mode', 'StackMode'], 'parent', 'window',
     [0, sub {
	 my($m) = 0;
	 $m  = 1 if exists $_[0]{'x'};
	 $m |= 2 if exists $_[0]{'y'};
	 $m |= 4 if exists $_[0]{'width'};
	 $m |= 8 if exists $_[0]{'height'};
	 $m |= 16 if exists $_[0]{'border_width'};
	 $m |= 32 if exists $_[0]{'sibling'};
	 $m |= 64 if exists $_[0]{'stack_mode'};
	 $_[0]{'mask'} = $m;
     }],
     ['sibling', ['None']], 'x', 'y', 'width', 'height', 'border_width',
     'mask',
     [sub {
	 my($m) = $_[0]{'mask'};
	 delete $_[0]{'x'} unless $m & 1;
	 delete $_[0]{'y'} unless $m & 2;
	 delete $_[0]{'width'} unless $m & 4;
	 delete $_[0]{'height'} unless $m & 8;
	 delete $_[0]{'border_width'} unless $m & 16;
	 delete $_[0]{'sibling'} unless $m & 32;
	 delete $_[0]{'stack_mode'} unless $m & 64;
	 }, 0]],
#    elsif ($code == 24) # GravityNotify
    ["xxxxLLssxxxxxxxxxxxxxxxx", 'event', 'window', 'x', 'y'],
#    elsif ($code == 25) # ResizeRequest
    ["xxxxLSSxxxxxxxxxxxxxxxxxxxx", 'window', 'width', 'height'],
#    elsif ($code == 26 or $code == 27) # Circulate(Notify|Request)
    (["xxxxLLxxxxCxxxxxxxxxxxxxxx", 'event', 'window',
      ['place', 'CirculatePlace']]) x 2,
#    elsif ($code == 28) # PropertyNotify
    ["xxxxLLLCxxxxxxxxxxxxxxx", 'window', 'atom', 'time',
    ['state', 'PropertyNotifyState']],
#    elsif ($code == 29) # SelectionClear
    ["xxxxLLLxxxxxxxxxxxxxxxx", 'time', 'owner', 'selection'],
#    elsif ($code == 30) # SelectionRequest
    ["xxxxLLLLLLxxxx", ['time', ['CurrentTime']], 'owner', 'requestor',
    'selection', 'target', ['property', ['None']]],
#    elsif ($code == 31) # SelectionNotify
    ["xxxxLLLLLxxxxxxxx", ['time', ['CurrentTime']], 'requestor', 'selection',
    'target', ['property', ['None']]],
#    elsif ($code == 32) # ColormapNotify
    ["xxxxLLCCxxxxxxxxxxxxxxxxxx", 'window', ['colormap', ['None']], 'new',
    ['state', 'ColormapNotifyState']],
#    elsif ($code == 33) # ClientMessage
    [sub {
	my($self, $data, %h) = @_;
	my($format) = unpack("C", substr($data, 1, 1));
	my($win, $type) = unpack("LL", substr($data, 4, 8));
	my($dat) = substr($data, 12, 20);
	return (%h, 'window' => $win, 'type' => $type, 'data' => $dat,
		'format' => $format);
    }, sub {
 	my $self = shift;
 	my(%h) = @_;
 	my($data) = pack("xCxxLL", $h{'format'}, $h{window}, $h{type}) 
	    . substr($h{data}, 0, 20);
 	return ($data, 1);
     }],
#    elsif ($code == 34) # MappingNotify
    ["xxxxCCCxxxxxxxxxxxxxxxxxxxxxxxxx", ['request', 'MappingNotifyRequest'],
    'first_keycode', 'count']
    );

sub unpack_event {
    my $self = shift;
    my($data) = @_;
    my($code, $detail, $seq) = unpack("CCS", substr($data, 0, 4));
    my($name) = $self->do_interp('Events', $code & 127);
    my(%ret);
    $ret{'synthetic'} = 1 if $code & 128; $code &= 127;
    $ret{'name'} = $name;
    $ret{'code'} = $code;
    $ret{'sequence_number'} = $seq;
    my($info);
    $info = $self->{'events'}[$code] || $self->{'ext_events'}[$code];

    if ($info) {
	my(@i) = @$info;
	if (ref $i[0] eq "CODE") {
	    %ret = &{$i[0]}($self, $data, %ret);
	} else {
	    my($format, @fields) = @i;
	    my(@unpacked) = unpack($format, $data);
	    my($f);
	    for $f (@fields) {
		if (not ref $f) {
		    $ret{$f} = shift @unpacked;
		} else {
		    my(@f) = @$f;
		    if (ref $f[0] eq "CODE" or ref $f[1] eq "CODE") {
			&{$f[0]}(\%ret) if $f[0];
		    } elsif (not ref $f[1]) {
			$ret{$f[0]} = $self->interp($f[1], shift @unpacked);
		    } else {
			my($v) = shift @unpacked;
			$v = $f[1][$v] if $self->{'do_interp'} and 
			    ($v == 0 or $v == 1 && $f[1][1]);
			$ret{$f[0]} = $v;
		    }
		}
	    }
	}
    } else {
        carp "Unknown event (code $code)!";
        $ret{'data'} = $data;
    }
    return %ret;
}

sub pack_event {
    my $self = shift;
    my(%h) = @_;
    my($code) = $h{code};
    $code = $self->num('Events', $h{name}) unless exists $h{code};
    $h{sequence_number} = 0 unless $h{sequence_number};
    $h{synthetic} = 0 unless $h{synthetic};
    my($data, $info);
    my($do_seq) = 1;
    $info = $self->{'events'}[$code] || $self->{'ext_events'}[$code];

    if ($info) {
	my(@i) = @$info;
	if (ref $i[0] eq "CODE") {
	    ($data, $do_seq) = &{$i[1]}($self, %h);
	} else {
	    my($format, @fields) = @i;
	    my(@topack) = ();
	    my($f);
	    for $f (@fields) {
		if (not ref $f) {
		    push @topack, $h{$f};
		} else {
		    my(@f) = @$f;
		    if (ref $f[0] eq "CODE" or ref $f[1] eq "CODE") {
			&{$f[1]}(\%h) if $f[1];
		    } elsif (not ref $f[1]) {
			push @topack, $self->num($f[1], $h{$f[0]});
		    } else {
			my($v) = $h{$f[0]};
			$v = 0 if $v eq $f[1][0];
			$v = 1 if $v eq $f[1][1] and $f[1][1];
			push @topack, $v;
		    }
		}
	    }
	    $data = pack($format, @topack);
	}
	substr($data, 2, 2) = pack("S", $h{sequence_number}) if $do_seq;
	substr($data, 0, 1) = pack("C", $code | ($h{synthetic} ? 128 : 0));
    } else {
        carp "Unknown event (code $code)!";
        return pack("Cxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", $code);
    }
    return $data;
}

sub unpack_event_mask {
    my $self = shift;
    my($x) = @_;
    my(@ans, $i);
    for $i (@{$Const{'EventMask'}}) {
	push @ans, $i if $x & 1;
	$x >>= 1;
    }
    @ans;
}

sub pack_event_mask {
    my $self = shift;
    my(@x) = @_;
    my($i, $mask);
    $mask = 0;
    for $i (@x) {
	$mask |= 1 << $self->num('EventMask', $i);
    }
    return $mask;
}

sub format_error_msg {
    my($self, $data) = @_;
    my($type, $seq, $info, $minor_op, $major_op)
	= unpack("xCSLSCxxxxxxxxxxxxxxxxxxxxx", $data);
    my($t);
    $t = join("", "Protocol error: bad $type (",
	      $self->do_interp('Error', $type), "); ",
	      "Sequence Number $seq\n",
	      " Opcode ($major_op, $minor_op) = ",
	      ($self->do_interp('Request', $major_op)
	      or $self->{'ext_request'}{$major_op}[$minor_op][0]), "\n");
    if ($type == 2) {
	$t .= " Bad value $info (" . hexi($info) . ")\n";
    } elsif ($self->{'error_type'}[$type] == 1 or
	     $self->{'ext_error_type'}[$type] == 1) {
	$t .= " Bad resource $info (" . hexi($info) . ")\n";
    }
    return $t;
}

sub default_error_handler {
    my($self, $data) = @_;
    croak($self->format_error_msg($data));
}

sub handle_input {
    my $self = shift;
    my($type_b, $type);
    $self->flush;
    $type_b = $self->get(1);
    $type = unpack "C", $type_b;
    if ($type == 0) {
	my $data = $type_b . $self->get(31);
	&{$self->{'error_handler'}}($self, $data);
	$self->{'error_seq'} = unpack("xxSx28", $data);
	return -1;
    } elsif ($type > 1) {
	if ($self->{'event_handler'} eq "queue") {
	    push @{$self->{'event_queue'}}, $type_b . $self->get(31);
	} else {
	    &{$self->{'event_handler'}}
	      ($self->unpack_event($type_b . $self->get(31)));
	}
	return -$type;
    } else {
	# $type == 1
	my($data) = $self->get(31);
	my($seq, $len) = unpack "SL", substr($data, 1, 6);
	$data = join("", $type_b, $data, $self->get(4 * $len));
	if ($self->{'replies'}->{$seq}) {
	    ${$self->{'replies'}->{$seq}} = $data;
	    return $seq;
	} else {
	    carp "Unexpected reply to request $seq",
	    " (of $self->{'sequence_num'})";
	    return $seq;
	}
    }
}

sub handle_input_for {
    my($self, $seq) = @_;
    for (;;) {
	my $stat = $self->handle_input();
	return if $stat == $seq; # Normal reply for this request
	return if $stat == -1 && $self->{'error_seq'} == $seq; # Error for this
    }
}

sub dequeue_event {
    my $self = shift;
    my($data) = shift @{$self->{'event_queue'}};
    return () unless $data;
    return $self->unpack_event($data);
}

sub next_event {
    my $self = shift;
    if ($self->{'event_handler'} ne "queue") {
	carp "Setting event_handler to 'queue' to avoid infinite loop",
	     "in next_event()";
	$self->{'event_handler'} = "queue";
    }
    my(%e);
    $self->handle_input until %e = $self->dequeue_event;
    return %e;
}

sub next_sequence {
    my $self = shift;
    my $ret = $self->{'sequence_num'}++;
    $self->{'sequence_num'} &= 0xffff;
    return $ret;
}

sub add_reply {
    my $self = shift;
    my($seq, $var) = @_;
    $self->{'replies'}->{$seq} = $var;
}

sub delete_reply {
    my $self = shift;
    my($seq) = @_;
    delete $self->{'replies'}->{$seq};
}

my(@Requests) =
(0,
 ['CreateWindow', sub {
     my $self = shift;
     my($wid, $parent, $class, $depth, $visual, $x, $y, $width,
	$height, $border_width, %values) = @_;
     my($mask, $i, @values);
     $mask = 0;
     for $i (0 .. 14) {
	 if (exists $values{$Attributes_ValueMask[$i][0]}) {
	     $mask |= (1 << $i);
	     push @values, 
	     &{$Attributes_ValueMask[$i][1]}
	       ($self, $values{$Attributes_ValueMask[$i][0]});
	 }
     }
     $visual = 0 if $visual eq 'CopyFromParent';
     $class  = $self->num('Class', $class);
     return pack("LLssSSSSLL", $wid, $parent, $x, $y, $width, $height,
		 $border_width, $class, $visual, $mask) .
		     join("", @values), $depth;
 }],

 ['ChangeWindowAttributes', sub {
     my $self = shift;
     my($wid, %values) = @_;
     my($mask, $i, @values);
     $mask = 0;
     for $i (0 .. 14) {
	 if (exists $values{$Attributes_ValueMask[$i][0]}) {
	     $mask |= (1 << $i);
	     push @values, 
	     &{$Attributes_ValueMask[$i][1]}
	     ($self, $values{$Attributes_ValueMask[$i][0]});
	 }
     }
     return pack("LL", $wid, $mask) . join "", @values;
 }],

 ['GetWindowAttributes', sub {
     my $self = shift;
     my($wid) = @_;
     return pack "L", $wid;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($backing_store, $visual, $class, $bit_gravity, $win_gravity,
	$backing_planes, $backing_pixel, $save_under, $map_is_installed,
	$map_state, $override_redirect, $colormap, $all_event_masks,
	$your_event_mask, $do_not_propagate_mask)
	 = unpack("xCxxxxxxLSCCLLCCCCLLLS", $data);

     $colormap = "None" if !$colormap and $self->{'do_interp'};

     return ("backing_store" => $self->interp('BackingStore', $backing_store),
	     "visual" => $visual,
	     "class" => $self->interp('Class', $class),
	     "bit_gravity" => $self->interp('BitGravity', $bit_gravity),
	     "win_gravity" => $self->interp('WinGravity', $win_gravity),
	     "backing_planes" => $backing_planes,
	     "backing_pixel" => $backing_pixel, "save_under" => $save_under,
	     "map_is_installed" => $map_is_installed,
	     "map_state" => $self->interp('MapState', $map_state),
	     "override_redirect" => $override_redirect,
	     "colormap" => $colormap, "all_event_masks" => $all_event_masks,
	     "your_event_mask" => $your_event_mask,
	     "do_not_propagate_mask" => $do_not_propagate_mask);
 }],

 ['DestroyWindow', sub {
     my $self = shift;
     my($wid) = @_;
     return pack "L", $wid;
 }],

 ['DestroySubwindows', sub {
     my $self = shift;
     my($wid) = @_;
     return pack "L", $wid;
 }],

 ['ChangeSaveSet', sub {
     my $self = shift;
     my($mode, $wid) = @_;
     $mode = 0 if $mode eq "Insert";
     $mode = 1 if $mode eq "Delete";
     return pack("L", $wid), $mode;
 }],

 ['ReparentWindow', sub {
     my $self = shift;
     my($wid, $new_parent, $x, $y) = @_;
     return pack "LLss", $wid, $new_parent, $x, $y;
 }],

 ['MapWindow', sub {
     my $self = shift;
     my($wid) = @_;
     return pack "L", $wid;
 }],

 ['MapSubwindows', sub {
     my $self = shift;
     my($wid) = @_;
     return pack "L", $wid;
 }],

 ['UnmapWindow', sub {
     my $self = shift;
     my($wid) = @_;
     return pack "L", $wid;
 }],

 ['UnmapSubwindows', sub {
     my $self = shift;
     my($wid) = @_;
     return pack "L", $wid;
 }],

 ['ConfigureWindow', sub {
     my $self = shift;
     my($wid, %values) = @_;
     my($mask, $i, @values);
     $mask = 0;
     for $i (0 .. 6) {
	 if (exists $values{$Configure_ValueMask[$i][0]}) {
	     $mask |= (1 << $i);
	     push @values, 
	     &{$Configure_ValueMask[$i][1]}
	     ($self, $values{$Configure_ValueMask[$i][0]});
	 }
     }
     return pack("LSxx", $wid, $mask) . join "", @values;
 }],

 ['CirculateWindow', sub {
     my $self = shift;
     my($wid, $dir) = @_;
     $dir = $self->num('CirculateDirection', $dir);
     return pack("L", $wid), $dir;
 }],

 ['GetGeometry', sub {
     my $self = shift;
     my($drawable) = @_;
     return pack "L", $drawable;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($depth, $root, $x, $y, $width, $height, $border_width)
	 = unpack("xCxxxxxxLssSSSxxxxxxxxxx", $data);

     return ("depth" => $depth, "root" => $root, "x" => $x, "y" => $y,
	     "width" => $width, "height" => $height,
	     "border_width" => $border_width);
 }],

 ['QueryTree', sub {
     my $self = shift;
     my($wid) = @_;
     return pack "L", $wid;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($root, $parent, $n)
	 = unpack("xxxxxxxxLLSxxxxxxxxxxxxxx", substr($data, 0, 32));

     $parent = "None" if $parent == 0 and $self->{'do_interp'};

     return ($root, $parent, unpack("L*", substr($data, 32)));
 }],

 ['InternAtom', sub {
     my $self = shift;
     my($string, $only_if_exists) = @_;
     return pack("Sxx" . padded($string), length($string), $string),
            $only_if_exists;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($atom) = unpack("xxxxxxxxLxxxxxxxxxxxxxxxxxxxx", $data);
     $atom = "None" if $atom == 0 and $self->{'do_interp'};
     return $atom;
 }],

 ['GetAtomName', sub {
     my $self = shift;
     my($atom) = @_;
     return pack "L", $atom;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($len) = unpack "xxxxxxxxSxxxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32);
     return substr($data, 32, $len);
 }],

 ['ChangeProperty', sub {
     my $self = shift;
     my($window, $property, $type, $format, $mode, $data) = @_;
     $mode = $self->num('ChangePropertyMode', $mode);
     my($x) = $format / 8;
     return pack("LLLCxxxL" . padded($data), $window, $property, $type,
		 $format, length($data) / $x, $data), $mode;
 }],

 ['DeleteProperty', sub {
     my $self = shift;
     my($wid, $atom) = @_;
     return pack "LL", $wid, $atom;
 }],

 ['GetProperty', sub {
     my $self = shift;
     my($wid, $prop, $type, $offset, $length, $delete) = @_;
     $type = 0 if $type eq "AnyPropertyType";
     return pack("LLLLL", $wid, $prop, $type, $offset, $length), $delete;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($format, $type, $bytes_after, $len) =
	 unpack "xCxxxxxxLLLxxxxxxxxxxxx", substr($data, 0, 32);
     my($m) = $format / 8;
     my($val) = substr($data, 32, $len * $m);
     return ($val, $type, $format, $bytes_after);
 }],

 ['ListProperties', sub {
     my $self = shift;
     my($wid) = @_;
     return pack "L", $wid;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n) = unpack "xxxxxxxxSxxxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32);
     return unpack "L*", substr($data, 32, $n * 4);
 }],

 ['SetSelectionOwner', sub {
     my $self = shift;
     my($selection, $owner, $time) = @_;
     $owner = 0 if $owner eq "None";
     $time = 0 if $time eq "CurrentTime";
     return pack "LLL", $owner, $selection, $time;
 }],

 ['GetSelectionOwner', sub {
     my $self = shift;
     my($selection) = @_;
     return pack "L", $selection;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($win) = unpack "xxxxxxxxLxxxxxxxxxxxxxxxxxxxx", $data;
     $win = "None" if $win == 0 and $self->{'do_interp'};
     return $win;
 }],

 ['ConvertSelection', sub {
     my $self = shift;
     my($selection, $target, $prop, $requestor, $time) = @_;
     $prop = 0 if $prop eq "None";
     $time = 0 if $time eq "CurrentTime";
     return pack("LLLLL", $requestor, $selection, $target, $prop, $time);
 }],

 ['SendEvent', sub {
     my $self = shift;
     my($destination, $propagate, $event_mask, $event) = @_;
     $destination = 0 if $destination eq "PointerWindow";
     $destination = 1 if $destination eq "InputFocus";
     return pack("LL", $destination, $event_mask) . $event, $propagate;
 }],

 ['GrabPointer', sub {
     my $self = shift;
     my($window, $owner_events, $event_mask, $pointer_mode, $keybd_mode,
	$confine_window, $cursor, $time) = @_;
     $pointer_mode = $self->num('SyncMode', $pointer_mode);
     $keybd_mode = $self->num('SyncMode', $keybd_mode);
     $confine_window = 0 if $confine_window eq "None";
     $cursor = 0 if $cursor eq "None";
     $time = 0 if $time eq "CurrentTime";
     return pack("LSCCLLL", $window, $event_mask, $pointer_mode, $keybd_mode,
		 $confine_window, $cursor, $time), $owner_events;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($status) = unpack("xCxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", $data);
     return $self->interp('GrabStatus', $status);
 }],

 ['UngrabPointer', sub {
     my $self = shift;
     my($time) = @_;
     $time = 0 if $time eq 'CurrentTime';
     return pack "L", $time;
 }],

 ['GrabButton', sub {
     my $self = shift;
     my($modifiers, $button, $win, $owner_events, $mask, $p_mode, $k_mode,
	$confine_w, $cursor) = @_;
     $p_mode = $self->num('SyncMode', $p_mode);
     $k_mode = $self->num('SyncMode', $k_mode);
     $confine_w = 0 if $confine_w eq "None";
     $cursor = 0 if $cursor eq "None";
     $button = 0 if $button eq "AnyButton";
     $modifiers = 0x8000 if $modifiers eq "AnyModifier";
     return pack("LSCCLLCxS", $win, $mask, $p_mode, $k_mode, $confine_w,
		 $cursor, $button, $modifiers), $owner_events;
 }],

 ['UngrabButton', sub {
     my $self = shift;
     my($modifiers, $button, $win) = @_;
     $button = 0 if $button eq "AnyButton";
     $modifiers = 0x8000 if $modifiers eq "AnyModifier";
     return pack("LSxx", $win, $modifiers), $button;
 }],

 ['ChangeActivePointerGrab', sub {
     my $self = shift;
     my($mask, $cursor, $time) = @_;
     $cursor = 0 if $cursor eq "None";
     $time = 0 if $time eq "CurrentTime";
     return pack "LLSxx", $cursor, $time, $mask;
 }],

 ['GrabKeyboard', sub {
     my $self = shift;
     my($win, $owner_events, $p_mode, $k_mode, $time) = @_;
     $time = 0 if $time eq "CurrentTime";
     $p_mode = $self->num('SyncMode', $p_mode);
     $k_mode = $self->num('SyncMode', $k_mode);
     return pack("LLCCxx", $win, $time, $p_mode, $k_mode), $owner_events;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($status) = unpack("xCxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", $data);
     return $self->interp('GrabStatus', $status);
 }],

 ['UngrabKeyboard', sub {
     my $self = shift;
     my($time) = @_;
     $time = 0 if $time eq "CurrentTime";
     return pack("L", $time);
 }],

 ['GrabKey', sub {
     my $self = shift;
     my($key, $modifiers, $win, $owner_events, $p_mode, $k_mode) = @_;
     $modifiers = 0x8000 if $modifiers eq "AnyModifier";
     $key = 0 if $key eq "AnyKey";
     $p_mode = $self->num('SyncMode', $p_mode);
     $k_mode = $self->num('SyncMode', $k_mode);
     return pack("LSCCCxxx", $win, $modifiers, $key, $p_mode, $k_mode),
                 $owner_events;
 }],

 ['UngrabKey', sub {
     my $self = shift;
     my($key, $modifiers, $win) = @_;
     $key = 0 if $key eq "AnyKey";
     $modifiers = 0x8000 if $modifiers eq "AnyModifier";
     return pack("LSxx", $win, $modifiers), $key;
 }],

 ['AllowEvents', sub {
     my $self = shift;
     my($mode, $time) = @_;
     $mode = $self->num('AllowEventsMode', $mode);
     $time = 0 if $time eq "CurrentTime";
     return pack("L", $time), $mode;
 }],

 ['GrabServer', sub {
     my $self = shift;
     return "";
 }],

 ['UngrabServer', sub {
     my $self = shift;
     return "";
 }],

 ['QueryPointer', sub {
     my $self = shift;
     my($window) = @_;
     return pack "L", $window;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($same_s, $root, $child, $root_x, $root_y, $win_x, $win_y, $mask)
	 = unpack "xCxxxxxxLLssssSxxxxxx", $data;
     $child = 'None' if $child == 0 and $self->{'do_interp'};
     return ('same_screen' => $same_s, 'root' => $root, 'child' => $child,
	     'root_x' => $root_x, 'root_y' => $root_y, 'win_x' => $win_x,
	     'win_y' => $win_y, 'mask' => $mask);
 }],

 ['GetMotionEvents', sub {
     my $self = shift;
     my($start, $stop, $win) = @_;
     $start = 0 if $start eq "CurrentTime";
     $stop = 0 if $stop eq "CurrentTime";
     return pack "LLL", $win, $start, $stop;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n) = unpack "xxxxxxxxLxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32);
     my($events) = substr($data, 32, 8 * $n);
     my(@ret, $off);
     for $off (0 .. $n - 1)
     {
	 push @ret, [unpack "Lss", substr($events, 8 * $off, 8)];
     }
     return @ret;
 }],

 ['TranslateCoordinates', sub {
     my $self = shift;
     my($src_w, $dest_w, $src_x, $src_y) = @_;
     return pack "LLss", $src_w, $dest_w, $src_x, $src_y;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($same_screen, $child, $dest_x, $dest_y) =
	 unpack "xCxxxxxxLssxxxxxxxxxxxxxxxx", $data;
     $child = "None" if $child == 0 and $self->{'do_interp'};
     return ($same_screen, $child, $dest_x, $dest_y);
 }],

 ['WarpPointer', sub {
     my $self = shift;
     my($src_w, $dst_w, $src_x, $src_y, $src_width, $src_height, $dst_x,
	$dst_y) = @_;
     $src_w = 0 if $src_w eq "None";
     $dst_w = 0 if $dst_w eq "None";
     return pack("LLssSSss", $src_w, $dst_w, $src_x, $src_y, $src_width,
		 $src_height, $dst_x, $dst_y);
 }],

 ['SetInputFocus', sub {
     my $self = shift;
     my($focus, $revert_to, $time) = @_;
     $revert_to = $self->num('InputFocusRevertTo', $revert_to);
     $focus = 0 if $focus eq "None";
     $focus = 1 if $focus eq "ParentRoot";
     $time = 0 if $time eq "CurrentTime";
     return pack("LL", $focus, $time), $revert_to; 
 }],

 ['GetInputFocus', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($revert_to, $focus) =
	 unpack "xCxxxxxxLxxxxxxxxxxxxxxxxxxxx", $data;
     $revert_to = $self->interp('InputFocusRevertTo', $revert_to);
     $focus = "None" if $focus == 0 and $self->{'do_interp'};
     $focus = "PointerRoot" if $focus == 1 and $self->{'do_interp'};
     return ($focus, $revert_to);
 }],

 ['QueryKeymap', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     return substr($data, 8, 32);
 }],

 ['OpenFont', sub {
     my $self = shift;
     my($fid, $name) = @_;
     return pack("LSxx" . padded($name), $fid, length($name), $name);
 }],

 ['CloseFont', sub {
     my $self = shift;
     my($font) = @_;
     return pack "L", $font;
 }],

 ['QueryFont', sub {
     my $self = shift;
     my($font) = @_;
     return pack "L", $font;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($min_bounds) = substr($data, 8, 12);
     my($max_bounds) = substr($data, 24, 12);
     my($min_char_or_byte2, $max_char_or_byte2, $default_char, $n,
	$draw_direction, $min_byte1, $max_byte1, $all_chars_exist,
	$font_ascent, $font_descent, $m) = unpack("SSSSCCCCssL",
						  substr($data, 40, 20));
     my($properties) = substr($data, 60, 8 * $n);
     my($char_infos) = substr($data, 60 + 8 * $n, 12 * $m);
     $draw_direction = $self->interp('DrawDirection', $draw_direction);
     my(%ret) = ('min_char_or_byte2' => $min_char_or_byte2,
		 'max_char_or_byte2' => $max_char_or_byte2,
		 'default_char' => $default_char, 
		 'draw_direction' => $draw_direction,
		 'min_byte1' => $min_byte1, 'max_byte1' => $max_byte1,
		 'all_chars_exist' => $all_chars_exist,
		 'font_ascent' => $font_ascent,
		 'font_descent' => $font_descent);

     $ret{'min_bounds'} = [unpack("sssssS", $min_bounds)];
     $ret{'max_bounds'} = [unpack("sssssS", $max_bounds)];
     my($i, @char_infos, %font_props);
     for $i (0 .. $m - 1) {
	 push @char_infos, [unpack("sssssS",
				   substr($char_infos, 12 * $i, 12))];
     }
     for $i (0 .. $n - 1) {
	 my($atom, $value) = unpack("LL", substr($properties, 8 * $i, 8));
	 $font_props{$atom} = $value;
     }
     $ret{'properties'} = {%font_props};
     $ret{'char_infos'} = [@char_infos];
     return %ret;
 }],

 ['QueryTextExtents', sub {
     my $self = shift;
     my($font, $string) = @_;
     return pack("L" . padded($string), $font, $string), (pad($string) == 2);
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($draw_direction, $font_a, $font_d, $overall_a, $overall_d, $overall_w,
	$overall_l, $overall_r) = unpack("xCxxxxxxsssslllxxxx", $data);
     $draw_direction = $self->interp('DrawDirection', $draw_direction);
     return ('draw_direction' => $draw_direction, 'font_ascent' => $font_a,
	     'font_descent' => $font_d, 'overall_ascent' => $overall_a,
	     'overall_descent' => $overall_d, 'overall_width' => $overall_w,
	     'overall_left' => $overall_l, 'overall_right' => $overall_r);
 }],

 ['ListFonts', sub {
     my $self = shift;
     my($pat, $max) = @_;
     return pack("SS" . padded($pat), $max, length($pat), $pat);
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n) = unpack("xxxxxxxxSxxxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32));
     my($list) = substr($data, 32);
     my(@ret, $offset, $len, $i);
     $offset = 0;
     while ($i++ < $n) {
	 $len = unpack("C", substr($list, $offset, 1));
	 push @ret, substr($list, $offset + 1, $len);
	 $offset += $len + 1;
     }
     return @ret;
 }],

 ['ListFontsWithInfo', sub {
     my $self = shift;
     my($pat, $max) = @_;
     return pack("SS" . padded($pat), $max, length($pat), $pat);
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n) = unpack("C", substr($data, 1, 1));
     return () if $n == 0;
     my($min_bounds) = substr($data, 8, 12);
     my($max_bounds) = substr($data, 24, 12);
     my($min_char_or_byte2, $max_char_or_byte2, $default_char, $m,
	$draw_direction, $min_byte1, $max_byte1, $all_chars_exist,
	$font_ascent, $font_descent) = unpack("SSSSCCCCssxxxx", 
					      substr($data, 40, 20));
     my($properties) = substr($data, 60, 8 * $m);
     my($name) = substr($data, 60 + 8 * $m, $n);
     $draw_direction = $self->interp('DrawDirection', $draw_direction);
     my(%ret) = ('min_char_or_byte2' => $min_char_or_byte2,
		 'max_char_or_byte2' => $max_char_or_byte2,
		 'default_char' => $default_char, 
		 'draw_direction' => $draw_direction,
		 'min_byte1' => $min_byte1, 'max_byte1' => $max_byte1,
		 'all_chars_exist' => $all_chars_exist,
		 'font_ascent' => $font_ascent,
		 'font_descent' => $font_descent, 'name' => $name);

     $ret{'min_bounds'} = [unpack("sssssS", $min_bounds)];
     $ret{'max_bounds'} = [unpack("sssssS", $max_bounds)];
     my($i, %font_props);
     for $i (0 .. $m - 1) {
	 my($atom, $value) = unpack("LL", substr($properties, 8 * $i, 8));
	 $font_props{$atom} = $value;
     }
     $ret{'properties'} = {%font_props};
     return %ret;
 }, 'HASH'],

 ['SetFontPath', sub {
     my $self = shift;
     my(@dirs) = @_;
     my($n, $d, $path);
     for $d (@dirs) {
	 $d = pack("C", length $d) . $d;
	 $n++;
     }
     $path = join("", @dirs);
     return pack("Sxx" . padded($path), $n, $path);
 }],

 ['GetFontPath', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n) = unpack("xxxxxxxxSxxxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32));
     my($list) = substr($data, 32);
     my(@ret, $offset, $len, $i);
     $offset = 0;
     while ($i++ < $n) {
	 $len = unpack("C", substr($list, $offset, 1));
	 push @ret, substr($list, $offset + 1, $len);
	 $offset += $len + 1;
     }
     return @ret;
 }],

 ['CreatePixmap', sub {
     my $self = shift;
     my($pixmap, $drawable, $depth, $w, $h) = @_;
     return pack("LLSS", $pixmap, $drawable, $w, $h), $depth;
 }],

 ['FreePixmap', sub {
     my $self = shift;
     my($pixmap) = @_;
     return pack "L", $pixmap;
 }],

 ['CreateGC', sub {
     my $self = shift;
     my($gc, $drawable, %values) = @_;
     my($i, $mask, @values);
     $mask = 0;
     for $i (0 .. $#GC_ValueMask) {
	 if (exists $values{$GC_ValueMask[$i][0]}) {
	     $mask |= (1 << $i);
	     push @values, 
	       &{$GC_ValueMask[$i][1]}($self, $values{$GC_ValueMask[$i][0]});
	     delete $values{$GC_ValueMask[$i][0]};
	 }
     }
     croak "Invalid GC components: ", join(",", keys %values), "\n" if %values;
     return pack("LLL", $gc, $drawable, $mask) . join("", @values);
 }],

 ['ChangeGC', sub {
     my $self = shift;
     my($gc, %values) = @_;
     my($i, $mask, @values);
     $mask = 0;
     for $i (0 .. $#GC_ValueMask) {
	 if (exists $values{$GC_ValueMask[$i][0]}) {
	     $mask |= (1 << $i);
	     push @values, 
	       &{$GC_ValueMask[$i][1]}($self, $values{$GC_ValueMask[$i][0]});
	 }
     }
     return pack("LL", $gc,  $mask) . join("", @values);
 }],

 ['CopyGC', sub {
     my $self = shift;
     my($src, $dst, @values) = @_;
     my(%values, $i, $mask);
     $mask = 0;
     @values{@values} = (1) x @values;
     for $i (0 .. $#GC_ValueMask) {
	 $mask |= (1 << $i) if exists $values{$GC_ValueMask[$i][0]};
     }
     return pack "LLL", $src, $dst, $mask;
 }],

 ['SetDashes', sub {
     my $self = shift;
     my($gc, $offset, @dashes) = @_;
     my($dash_list) = pack("C*", @dashes);
     my($n) = length $dash_list;
     return pack("LSS" . padded($dash_list), $gc, $offset, $n, $dash_list);
 }],

 ['SetClipRectangles', sub {
     my $self = shift;
     my($gc, $clip_x_o, $clip_y_o, $ordering, @rects) = @_;
     $ordering = $self->num('ClipRectangleOrdering', $ordering);
     my($x);
     for $x (@rects) {
	 $x = pack("ssSS", @$x);
     }
     return pack("Lss", $gc, $clip_x_o, $clip_y_o) . join("", @rects),
            $ordering;
 }],

 ['FreeGC', sub {
     my $self = shift;
     my($gc) = @_;
     return pack "L", $gc;
 }],

 ['ClearArea', sub {
     my $self = shift;
     my($win, $x, $y, $w, $h, $exposures) = @_;
     return pack("LssSS", $win, $x, $y, $w, $h), $exposures;
 }],

 ['CopyArea', sub {
     my $self = shift;
     my($src_d, $dst_d, $gc, $src_x, $src_y, $w, $h, $dst_x, $dst_y) = @_;
     return pack("LLLssssSS", $src_d, $dst_d, $gc, $src_x, $src_y, $dst_x,
		 $dst_y, $w, $h); 
 }],

 ['CopyPlane', sub {
     my $self = shift;
     my($src_d, $dst_d, $gc, $src_x, $src_y, $w, $h, $dst_x, $dst_y, $plane)
	 = @_;
     return pack("LLLssssSSL", $src_d, $dst_d, $gc, $src_x, $src_y, $dst_x,
		 $dst_y, $w, $h, $plane);
 }],

 ['PolyPoint', sub {
     my $self = shift;
     my($drawable, $gc, $coord_mode, @points) = @_;
     $coord_mode = $self->num('CoordinateMode', $coord_mode);
     return pack("LLs*", $drawable, $gc, @points), $coord_mode;
 }],

 ['PolyLine', sub {
     my $self = shift;
     my($drawable, $gc, $coord_mode, @points) = @_;
     $coord_mode = $self->num('CoordinateMode', $coord_mode);
     return pack("LLs*", $drawable, $gc, @points), $coord_mode;
 }],

 ['PolySegment', sub {
     my $self = shift;
     my($drawable, $gc, @points) = @_;
     return pack("LLs*", $drawable, $gc, @points);
 }],

 ['PolyRectangle', sub {
     my $self = shift;
     my($drawable, $gc, @rects) = @_;
     my($rr);
     for $rr (@rects) {
	 $rr = pack("ssSS", @$rr);
     }
     return pack("LL", $drawable, $gc) . join("", @rects);
 }],

 ['PolyArc', sub {
     my $self = shift;
     my($drawable, $gc, @arcs) = @_;
     my($ar);
     for $ar (@arcs) {
	 $ar = pack("ssSSss", @$ar);
     }
     return pack("LL", $drawable, $gc) . join("", @arcs);
 }],

 ['FillPoly', sub {
     my $self = shift;
     my($drawable, $gc, $shape, $coord_mode, @points) = @_;
     $shape = $self->num('PolyShape', $shape);
     $coord_mode = $self->num('CoordinateMode', $coord_mode);
     return pack("LLCCxxs*", $drawable, $gc, $shape, $coord_mode, @points);
 }],

 ['PolyFillRectangle', sub {
     my $self = shift;
     my($drawable, $gc, @rects) = @_;
     my($rr);
     for $rr (@rects) {
	 $rr = pack("ssSS", @$rr);
     }
     return pack("LL", $drawable, $gc) . join("", @rects);
 }],

 ['PolyFillArc', sub {
     my $self = shift;
     my($drawable, $gc, @arcs) = @_;
     my($ar);
     for $ar (@arcs) {
	 $ar = pack("ssSSss", @$ar);
     }
     return pack("LL", $drawable, $gc) . join("", @arcs);
 }],

 ['PutImage', sub {
     my $self = shift;
     my($drawable, $gc, $depth, $w, $h, $x, $y, $left_pad, $format, $data) 
	 = @_;
     $format = $self->num('ImageFormat', $format);
     return pack("LLSSssCCxx" . padded($data), $drawable, $gc, $w, $h,
		 $x, $y, $left_pad, $depth, $data), $format;
 }],

 ['GetImage', sub {
     my $self = shift;
     my($drawable, $x, $y, $w, $h, $mask, $format) = @_;
     $format = $self->num('ImageFormat', $format);
     croak "GetImage() format must be (XY|Z)Pixmap" if $format == 0;
     return pack("LssSSL", $drawable, $x, $y, $w, $h, $mask), $format;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($depth, $visual) = unpack("xCxxxxxxLxxxxxxxxxxxxxxxxxxxx",
				  substr($data, 0, 32));
     return ($depth, $visual, substr($data, 32));
 }],

 ['PolyText8', sub {
     my $self = shift;
     my($drawable, $gc, $x, $y, @items) = @_;
     my(@i, $ir, @item, $n, $r, $items);
     for $ir (@items) {
	 if (not ref $ir) {
	     push @i, pack("CN", 255, $ir);
	 } else {
	     @item = @$ir;
	     $n = 0;
	     $r = length($item[1]);
	     while ($r > 0) {
		 if ($r >= 254) {
		     push @i, pack("Cc", 254, 0) . substr($item[1], $n, 254);
		     $n += 254;
		     $r -= 254;
		 } else {
		     push @i, pack("Cc", $r, $item[0]) . substr($item[1], $n);
		     $n += $r; # Superfluous
		     $r = 0; # $r -= $r would be more symmetrical
		 }
	     }
	 }
     }
     $items = join("", @i);
     return pack("LLss" . padded($items), $drawable, $gc, $x, $y, $items);
 }],

 ['PolyText16', sub {
     my $self = shift;
     my($drawable, $gc, $x, $y, @items) = @_;
     my(@i, $ir, @item, $n, $r, $items);
     for $ir (@items) {
	 if (not ref $ir) {
	     push @i, pack("CN", 255, $ir);
	 } else {
	     @item = @$ir;
	     $n = 0;
	     $r = length($item[1]);
	     while ($r > 0) {
		 if ($r >= 508) {
		     push @i, pack("Cc", 254, 0) . substr($item[1], $n, 508);
		     $n += 508;
		     $r -= 508;
		 } else {
		     push @i, pack("Cc", $r / 2, $item[0]) 
			 . substr($item[1], $n);
		     $n += $r; # Unnecessary
		     $r = 0; # $r -= $r would be more symmetrical
		 }
	     }
	 }
     }
     $items = join("", @i);
     return pack("LLss" . padded($items), $drawable, $gc, $x, $y, $items);
 }],

 ['ImageText8', sub {
     my $self = shift;
     my($drawable, $gc, $x, $y, $str) = @_;
     return pack("LLss" . padded($str), $drawable, $gc, $x, $y, $str),
            length($str);
 }],

 ['ImageText16', sub {
     my $self = shift;
     my($drawable, $gc, $x, $y, $str) = @_;
     return pack("LLss" . padded($str), $drawable, $gc, $x, $y, $str),
            length($str)/2;
 }],

 ['CreateColormap', sub {
     my $self = shift;
     my($mid, $visual, $win, $alloc) = @_;
     $alloc = 0 if $alloc eq "None";
     $alloc = 1 if $alloc eq "All";
     return pack("LLL", $mid, $win, $visual), $alloc;
 }],

 ['FreeColormap', sub {
     my $self = shift;
     my($cmap) = @_;
     return pack("L", $cmap);
 }],

 ['CopyColormapAndFree', sub {
     my $self = shift;
     my($mid, $src) = @_;
     return pack("LL", $mid, $src);
 }],

 ['InstallColormap', sub {
     my $self = shift;
     my($cmap) = @_;
     return pack("L", $cmap);
 }],

 ['UninstallColormap', sub {
     my $self = shift;
     my($cmap) = @_;
     return pack("L", $cmap);
 }],

 ['ListInstalledColormaps', sub {
     my $self = shift;
     my($win) = @_;
     return pack("L", $win);
 }, sub {
     my $self = shift;
     my($data) = @_;
     return unpack("L*", substr($data, 32));
 }],

 ['AllocColor', sub {
     my $self = shift;
     my($cmap, $r, $g, $b) = @_;
     return pack("LSSSxx", $cmap, $r, $g, $b);
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($r, $g, $b, $pixel) = unpack("xxxxxxxxSSSxxLxxxxxxxxxxxx", $data);
     return ($pixel, $r, $g, $b);
 }],

 ['AllocNamedColor', sub {
     my $self = shift;
     my($cmap, $name) = @_;
     return pack("LSxx" . padded($name), $cmap, length($name), $name);
 }, sub {
     my $self = shift;
     my($data) = @_;
     return unpack("xxxxxxxxLSSSSSSxxxxxxxx", $data);
 }],

 ['AllocColorCells', sub {
     my $self = shift;
     my($cmap, $colors, $planes, $contig) = @_;
     return pack("LSS", $cmap, $colors, $planes), $contig; 
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n,$m) = unpack("xxxxxxxxSSxxxxxxxxxxxxxxxxxxxx",substr($data, 0, 32));
     return ([unpack("L*", substr($data, 32, 4 * $n))],
	     [unpack("L*", substr($data, 32 + 4 * $n, 4 * $m))]);
 }],

 ['AllocColorPlanes', sub {
     my $self = shift;
     my($cmap, $colors, $reds, $greens, $blues, $contig) = @_;
     return pack("LSSSS", $cmap, $colors, $reds, $greens, $blues), $contig;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n, $r_mask, $g_mask, $b_mask) = 
	 unpack("xxxxxxxxSxxLLLxxxxxxxx", substr($data, 0, 32));
     return ($r_mask, $g_mask, $b_mask, unpack("L*", substr($data, 32, 4*$n)));
 }],

 ['FreeColors', sub {
     my $self = shift;
     my($cmap, $mask, @pixels) = @_;
     return pack("LLL*", $cmap, $mask, @pixels);
 }],

 ['StoreColors', sub {
     my $self = shift;
     my($cmap, @actions) = @_;
     my($l, @l);
     for $l (@actions) {
	 @l = @$l;
	 if (@l == 4) {
	     $l = pack("LSSSCx", @l, 7);
	 } elsif (@l == 5) {
	     $l = pack("LSSSCx", @l);
	 } else {
	     croak "Wrong # of items in arg to StoreColors";	 
	 }
     }
     return pack("L", $cmap) . join("", @actions);
 }],

 ['StoreNamedColor', sub {
     my $self = shift;
     my($cmap, $pixel, $name, $do) = @_;
     return pack("LLSxx" . padded($name), $cmap, $pixel, length($name),
		 $name), $do;
 }],

 ['QueryColors', sub {
     my $self = shift;
     my($cmap, @pixels) = @_;
     return pack("LL*", $cmap, @pixels);
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n) = unpack("xxxxxxxxSxxxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32));
     my($i, @colors);
     for $i (0 .. $n - 1) {
	 push @colors, [unpack("SSSxx", substr($data, 32 + 8 * $i, 8))];
     }
     return @colors;
 }],

 ['LookupColor', sub {
     my $self = shift;
     my($cmap, $name) = @_;
     return pack("LSxx" . padded($name), $cmap, length($name), $name);
 }, sub {
     my $self = shift;
     my($data) = @_;
     return unpack("xxxxxxxxSSSSSSxxxxxxxxxxxx", $data);
 }],

 ['CreateCursor', sub {
     my $self = shift;
     my($cid, $src, $mask, $fr, $fg, $fb, $br, $bg, $bb, $x, $y) = @_;
     $mask = 0 if $mask eq "None";
     return pack("LLLSSSSSSSS", $cid, $src, $mask, $fr, $fg, $fb, $br, $bg,
		 $bb, $x, $y);
 }],

 ['CreateGlyphCursor', sub {
     my $self = shift;
     my($cid, $src_fnt, $mask_fnt, $src_ch, $mask_ch, $fr, $fg, $fb, $br,
	$bg, $bb) = @_;
     $mask_fnt = 0 if $mask_fnt eq "None";
     return pack("LLLSSSSSSSS", $cid, $src_fnt, $mask_fnt, $src_ch, $mask_ch,
		 $fr, $fg, $fb, $br, $bg, $bb);
 }],

 ['FreeCursor', sub {
     my $self = shift;
     my($cursor) = @_;
     return pack("L", $cursor);
 }],

 ['RecolorCursor', sub {
     my $self = shift;
     my($cursor, $fr, $fg, $fb, $br, $bg, $bb) = @_;
     return pack("LSSSSSS", $cursor, $fr, $fg, $fb, $br, $bg, $bb);
 }],

 ['QueryBestSize', sub {
     my $self = shift;
     my($class, $drawable, $w, $h) = @_;
     $class = $self->num('SizeClass', $class);
     return pack("LSS", $drawable, $w, $h), $class;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($w, $h) = unpack("xxxxxxxxSSxxxxxxxxxxxxxxxxxxxx", $data);
     return ($w, $h);
 }],

 ['QueryExtension', sub {
     my $self = shift;
     my($name) = @_;
     return pack("Sxx" . padded($name), length($name), $name);
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($present, $major, $event, $error) = 
	 unpack("xxxxxxxxCCCCxxxxxxxxxxxxxxxxxxxx", $data);
     return () unless $present;
     return ($major, $event, $error);
 }],

 ['ListExtensions', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($num) = unpack("xCxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
		       substr($data, 0, 32));
     my($list) = substr($data, 32);
     my(@ret, $offset, $len, $i);
     $offset = 0;
     while ($i++ < $num) {
	 $len = unpack("C", substr($list, $offset, 1));
	 push @ret, substr($list, $offset + 1, $len);
	 $offset += $len + 1;
     }
     return @ret;
 }],

 ['ChangeKeyboardMapping', sub {
     my $self = shift;
     my($first, $m, @info) = @_;
     my($ar);
     for $ar (@info) {
	 $ar = pack("L$m", @{$ar}[0 .. $m - 1]);
     }
     return pack("CCxx", $first, $m) . join("", @info), scalar(@info);
 }],

 ['GetKeyboardMapping', sub {
     my $self = shift;
     my($first, $count) = @_;
     return pack("CCxx", $first, $count);
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n,$l) = unpack("xCxxLxxxxxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32));
     my(@ret, $i);
     for $i (0 .. $l/$n - 1) {
	 push @ret, [unpack("L$n", substr($data, 32 + $i * $n * 4))];
     }
     return @ret;
 }],

 ['ChangeKeyboardControl', sub {
     my $self = shift;
     my(%values) = @_;
     my($mask, $i, @values);
     $mask = 0;
     for $i (0 .. 7) {
	 if (exists $values{$KeyboardControl_ValueMask[$i][0]}) {
	     $mask |= (1 << $i);
	     push @values, 
	     &{$KeyboardControl_ValueMask[$i][1]}
	     ($self, $values{$KeyboardControl_ValueMask[$i][0]});
	 }
     }
     return pack("L", $mask). join "", @values;
 }],

 ['GetKeyboardControl', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($global_auto_repeat, $led_mask, $key_click_percent, $bell_percent,
	$bell_pitch, $bell_duration) 
	 = unpack("xCxxxxxxLCCSSxx", substr($data, 0, 20));
     my($auto_repeats) = substr($data, 20, 32);
     return ('global_auto_repeat' =>
	        $self->interp('LedMode', $global_auto_repeat),
	     'led_mask' => $led_mask,
	     'key_click_percent' => $key_click_percent,
	     'bell_percent' => $bell_percent, 'bell_pitch' => $bell_pitch,
	     'bell_duration' => $bell_duration, 
	     'auto_repeats' => $auto_repeats);
 }],

 ['Bell', sub {
     my $self = shift;
     my($percent) = @_;
     return "", unpack("C", pack("c", $percent)); # Ick
 }],

 ['ChangePointerControl', sub {
     my $self = shift;
     my($do_accel, $do_thresh, $num, $denom, $thresh) = @_;
     return pack("sssCC", $num, $denom, $thresh, $do_accel, $do_thresh);
 }],

 ['GetPointerControl', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($num, $deno, $thresh) = unpack("xxxxxxxxSSSxxxxxxxxxxxxxxxxxx", $data);
     return ($num, $deno, $thresh);
 }],

 ['SetScreenSaver', sub {
     my $self = shift;
     my($timeout, $interval, $pref_blank, $exposures) = @_;
     $pref_blank = $self->num('ScreenSaver', $pref_blank);
     $exposures = $self->num('ScreenSaver', $exposures);
     return pack("ssCCxx", $timeout, $interval, $pref_blank, $exposures);
 }],

 ['GetScreenSaver', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($timeout, $interval, $pref_blank, $exposures) 
	 = unpack("xxxxxxxxSSCCxxxxxxxxxxxxxxxxxx", $data);
     $pref_blank = $self->interp('ScreenSaver', $pref_blank);
     $exposures = $self->interp('ScreenSaver', $exposures);
     return ($timeout, $interval, $pref_blank, $exposures);
 }],

 ['ChangeHosts', sub {
     my $self = shift;
     my($mode, $family, $address) = @_;
     $mode = $self->num('HostChangeMode', $mode);
     $family = $self->num('HostFamily', $family);
     return pack("CxS" . padded($address), $family, length($address),
		 $address), $mode;
 }],

 ['ListHosts', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($mode, $n) = unpack("xCxxxxxxSxxxxxxxxxxxxxxxxxxxxxx",
			    substr($data, 0, 32));
     $mode = $self->interp('AccessMode', $mode);
     my(@ret, $fam, $off, $l);
     $off = 32;
     while ($n-- > 0) {
	 ($fam, $l) = unpack("CxS", substr($data, $off, 4));
	 $fam = $self->interp('HostFamily', $fam);
	 push @ret, [$fam, substr($data, $off + 4, $l)];
	 $off += 4 + $l + padding($l);
     }
     return ($mode, @ret);
 }],

 ['SetAccessControl', sub {
     my $self = shift;
     my($mode) = @_;
     $mode = $self->num('AccessMode', $mode);
     return "", $mode;
 }],

 ['SetCloseDownMode', sub {
     my $self = shift;
     my($mode) = @_;
     $mode = $self->num('CloseDownMode', $mode);
     return "", $mode;
 }],

 ['KillClient', sub {
     my $self = shift;
     my($rsrc) = @_;
     $rsrc = 0 if $rsrc eq "AllTemporary";
     return pack("L", $rsrc);
 }],

 ['RotateProperties', sub {
     my $self = shift;
     my($win, $delta, @atoms) = @_;
     return pack("LSsL*", $win, scalar(@atoms), $delta, @atoms);
 }],

 ['ForceScreenSaver', sub {
     my $self = shift;
     my($mode) = @_;
     $mode = $self->num('ScreenSaverAction', $mode);
     return "", $mode;
 }],

 ['SetPointerMapping', sub {
     my $self = shift;
     my(@map) = @_;
     my($map) = pack("C*", @map);
     return pack(padded($map), $map), length($map); 
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($status) = unpack("xCxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", $data);
     $status = $self->interp('MappingChangeStatus', $status);
     return $status;
 }],

 ['GetPointerMapping', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n) = unpack("xCxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32));
     return unpack("C*", substr($data, 32, $n));
 }],

 ['SetModifierMapping', sub {
     my $self = shift;
     my(@keycodes) = @_;
     my($n) = scalar(@{$keycodes[0]});
     my($kr);
     for $kr (@keycodes) {
	 $kr = pack("C$n", @$kr, (0) x (@$kr - $n));
     }
     return join("", @keycodes), $n;
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($status) = unpack("xCxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", $data);
     return $self->interp('MappingChangeStatus', $status);
 }],

 ['GetModifierMapping', sub {
     my $self = shift;
     return "";
 }, sub {
     my $self = shift;
     my($data) = @_;
     my($n) = unpack("xCxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", substr($data, 0, 32));
     my(@ret, $i);
     for $i (0 .. 7) {
	 push @ret, [unpack("C$n", substr($data, 32 + $n * $i))];
     }
     return @ret;
 }],

 0, 0, 0, 0, 0, 0, 0,

 ['NoOperation', sub {
     my $self = shift;
     my($len) = @_;
     $len = 1 unless defined $len;
     return "\0" x (($len - 1) * 4);
 }]);

my($i);
for $i (0 .. 127) {
    if (ref $Requests[$i] and $Requests[$i][0]) {
	$Const{'Request'}[$i] = $Requests[$i][0];
    } else {
	$Const{'Request'}[$i] = "";
    }
}

sub get_request {
    my $self = shift;
    my($name) = @_;
    my($major, $minor);
    $major = $self->num('Request', $name);
    if ($major =~ /^\d+$/) { # Core request
	return ($self->{'requests'}[$major], $major);
    } else { # Extension request
	croak "Unknown request `$name'" unless
	    exists $self->{'ext_request_num'}{$name};
	($major, $minor) = @{$self->{'ext_request_num'}{$name}};
	croak "Unknown request `$name'" if int($major) == 0;
	return ($self->{'ext_request'}{$major}[$minor], $major, $minor);
    }
}

sub assemble_request {
    my $self = shift;
    my($op, $args, $major, $minor) = (@_, 0);
    my($data);
    ($data, $minor) = (&{$op->[1]}($self, @$args), $minor);
    $minor = 0 unless defined $minor;
    my($len) = (length($data) / 4) + 1;
    croak "Request too long!\n" if $len > $self->{'maximum_request_length'};
    if ($len <= 65535) {
	return pack("CCS", $major, $minor, $len) . $data;
    } else {
	croak "Can't happen" unless $self->{'ext'}{'BIG_REQUESTS'};
	return pack("CCSL", $major, $minor, 0, $len) . $data;
    }
}

sub req {
    my $self = shift;
    my($name, @args) = @_;
    my($op, $major, $minor) = $self->get_request($name);
    if (@$op == 2) { # No reply
	$self->give($self->assemble_request($op, \@args, $major, $minor));
	$self->next_sequence();
    } elsif (@$op == 3) { # One reply
	my($seq, $data);
	$self->give($self->assemble_request($op, \@args, $major, $minor));
	$seq = $self->next_sequence();
	$self->add_reply($seq & 0xffff, \$data);
	$self->handle_input_for($seq & 0xffff);
	$self->delete_reply($seq & 0xffff);
	return &{$op->[2]}($self, $data);
    } elsif (@$op == 4) { # Many replies
	my($seq, $data, @stuff, @ret);
	$self->give($self->assemble_request($op, \@args, $major, $minor));
	$seq = $self->next_sequence();
	$self->add_reply($seq & 0xffff, \$data);
	for (;;) {
	    $data = 0; $self->handle_input_for($seq & 0xffff);
	    @stuff = &{$op->[2]}($self, $data);
	    last unless @stuff;
	    if ($op->[3] eq "ARRAY") {
		push @ret, [@stuff];
	    } elsif ($op->[3] eq "HASH") {
		push @ret, {@stuff};
	    } else {
		push @ret, @stuff;
	    }
	}
	$self->delete_reply($seq & 0xffff);
	return @ret;
    } else {
	croak "Can't handle request $name";
    }
}

sub robust_req {
    my $self = shift;
    my($name, @args) = @_;
    my($op, $major, $minor) = $self->get_request($name);
    # Luckily, ListFontsWithInfo can't cause any errors
    return [$self->req($name, @args)] if @$op == 4;
    my $err_data;
    local($self->{'error_handler'}) = sub { $err_data = $_[1]; };
    my($seq, $data);
    $self->give($self->assemble_request($op, \@args, $major, $minor));
    $seq = $self->next_sequence() & 0xffff;
    if (@$op == 2) {
	# No real reply, but fake up a request with a reply so we can
	# tell how long to wait before knowing the real request
	# succeeded
	my($fake_op, $fake_major) = $self->get_request("GetScreenSaver");
	$self->give($self->assemble_request($fake_op, [], $fake_major, 0));
	$seq = $self->next_sequence() & 0xffff;
    }
    $self->add_reply($seq, \$data);
    for (;;) {
	my $stat = $self->handle_input();
	if ($stat == $seq) {
	    $self->delete_reply($seq);
	    if (@$op == 3) {
		return [&{$op->[2]}($self, $data)];
	    } else {
		return [];
	    }
	} elsif ($stat == -1 && $self->{'error_seq'} == $seq) {
	    my($type, undef, $info, $minor_op, $major_op)
	      = unpack("xCSLSCxxxxxxxxxxxxxxxxxxxxx", $err_data);
	    return($self->interp('Error', $type),
		   $major_op, $minor_op, $info);
	}
    }
}

sub send {
    my $self = shift;
    my($name, @args) = @_;
    my($op, $major, $minor) = $self->get_request($name);
    $self->give($self->assemble_request($op, \@args, $major, $minor));
    return $self->next_sequence();
}

sub unpack_reply {
    my $self = shift;
    my($name, $data) = @_;
    my($op) = $self->get_request($name);
    return &{$op->[2]}($self, $data);
}

sub request {
    my $self = shift;
    $self->req(@_);
}

sub atom_name {
    my $self = shift;
    my($num) = @_;
    if ($self->{'atom_names'}->[$num]) {
	return $self->{'atom_names'}->[$num];
    } else {
	my($name) = $self->req('GetAtomName', $num);
	$self->{'atom_names'}->[$num] = $name;
	return $name;
    }
}

sub atom {
    my $self = shift;
    my($name) = @_;
    if (exists $self->{'atoms'}{$name}) {
	return $self->{'atoms'}{$name};
    } else {
	my($atom) = $self->req('InternAtom', $name, 0);
	$self->{'atoms'}{$name} = $atom;
	return $atom;
    }
}

sub choose_screen {
    my $self = shift;
    my($screen) = @_;
    my($k);
    for $k (keys %{$self->{'screens'}[$screen]}) {
	$self->{$k} = $self->{'screens'}[$screen]{$k};
    }
}

sub init_extension {
    my $self = shift;
    my($name) = @_;
    my($major, $event, $error) = $self->req('QueryExtension', $name)
	or return 0;
    $name =~ tr/-/_/;
    unless (defined eval { require("X11/Protocol/Ext/$name.pm") }) {
	return 0 if substr($@, 0, 30) eq "Can't locate X11/Protocol/Ext/";
	croak($@);
    }
    my($pkg) = "X11::Protocol::Ext::$name";
    my $obj = $pkg->new($self, $major, $event, $error);
    return 0 if not $obj;
    $self->{'ext'}{$name} = [$major, $event, $error, $obj];
}

sub init_extensions {
    my $self = shift;
    my($ext);
    for $ext ($self->req('ListExtensions')) {
	$self->init_extension($ext);
    }
}

sub new_rsrc {
    my $self = shift;
    if ($self->{'rsrc_id'} == $self->{'rsrc_max'} + 1) {
	if (exists $self->{'ext'}{'XC_MISC'}) {
	    my($start, $count) = $self->req('XCMiscGetXIDRange');
	    $self->{'rsrc_shift'} = 0;
	    $self->{'rsrc_id'} = 0;
	    $self->{'rsrc_base'} = $start;
	    $self->{'rsrc_max'} = $count - 1;
	    #print "Got $start $count\n";
	} else {
	    croak "Out of resource IDs, and we don't have XC_MISC";
	}
    }
    my $ret = ($self->{'rsrc_id'}++ << $self->{'rsrc_shift'})
      + $self->{'rsrc_base'};
    return $ret;
}

sub new {
    my($class) = shift;
    my($host, $dispnum, $screen);
    my($conn, $display, $family);
    if (@_ == 0 or $_[0] eq '') {
	if ($main::ENV{'DISPLAY'}) {
	    $display = $main::ENV{'DISPLAY'};
	} else {
	    carp "Can't find DISPLAY -- guessing `$Default_Display:0'";
	    $display = "$Default_Display:0";
	}
    } else {
	if (ref $_[0]) {
	    $conn = $_[0];
	} else {
	    $display = $_[0];
	}
    }

    unless ($conn) {
	$display =~ /^(?:[^:]*?\/)?(.*):(\d+)(?:.(\d+))?$/
	    or croak "Invalid display: `$display'\n";
	$host = $Default_Display unless $host = $1;
	$dispnum = $2;
	$screen = 0 unless $screen = $3;
	if ($] >= 5.00301) { # IO::Socket is bundled
	    if ($host eq 'unix') {
		require 'X11/Protocol/Connection/UNIXSocket.pm';
		$conn = X11::Protocol::Connection::UNIXSocket
		    ->open($host, $dispnum);
		$host = 'localhost';
		$family = 'Local';
	    } else {
		require 'X11/Protocol/Connection/INETSocket.pm';
		$conn = X11::Protocol::Connection::INETSocket
		    ->open($host, $dispnum);
		$family = 'Internet';
	    }
	} else { # Use FileHandle
	    if ($host eq 'unix') {
		require 'X11/Protocol/Connection/UNIXFH.pm';
		$conn = X11::Protocol::Connection::UNIXFH
		    ->open($host, $dispnum);
		$host = 'localhost';
		$family = 'Local';
	    } else {
		require 'X11/Protocol/Connection/INETFH.pm';
		$conn = X11::Protocol::Connection::INETFH
		    ->open($host, $dispnum);
		$family = 'Internet';
	    }
	}
    }

    my $self = {};
    bless $self, $class;
    $self->{'connection'} = $conn;
    $self->{'byte_order'} = $Byte_Order;
    $self->{'protocol_major_version'} = 11;
    $self->{'protocol_minor_version'} = 0;
    $self->{'const'} = \%Const;
    $self->{'const_num'} = \%Const_num;
    $self->{'authorization_protocol_name'} = '';
    $self->{'authorization_protocol_data'} = '';

    my($auth);

    if (ref($_[1]) eq "ARRAY") {
	($self->{'authorization_protocol_name'},
	 $self->{'authorization_protocol_data'}) = @{$_[1]};
    } elsif ($display and eval {require X11::Auth}) {
	$auth = X11::Auth->new() and 
	    ($self->{'authorization_protocol_name'},
	     $self->{'authorization_protocol_data'})
		= ($auth->get_by_host($host, $family, $dispnum), "", "");
    }

    $self->give(pack("A2 SSSS xx" .
		      padded($self->{'authorization_protocol_name'}) .
		      padded($self->{'authorization_protocol_data'}),
		      $self->{'byte_order'}, 
		      $self->{'protocol_major_version'}, 
		      $self->{'protocol_minor_version'},
		      length($self->{'authorization_protocol_name'}),
		      length($self->{'authorization_protocol_data'}),
		      $self->{'authorization_protocol_name'},
		      $self->{'authorization_protocol_data'}));

    $self->flush;
    my($ret) = ord($self->get(1));
    if ($ret == 0) {
	my($len, $major, $minor, $xlen) = unpack("CSSS", $self->get(7));
	my($reason) = $self->get($xlen * 4);
	croak("Connection to server failed -- (version $major.$minor)\n",
	      substr($reason, 0, $len));
    } elsif ($ret == 2) {
	croak("FIXME: authentication required\n");
    } elsif ($ret == 1) {
	my($major, $minor, $xlen) = unpack('xSSS', $self->get(7));
	($self->{'release_number'}, $self->{'resource_id_base'},
	 $self->{'resource_id_mask'}, $self->{'motion_buffer_size'},
	 my($vlen), $self->{'maximum_request_length'}, my($screens), 
	 my($formats), $self->{'image_byte_order'}, 
	 $self->{'bitmap_bit_order'}, $self->{'bitmap_scanline_unit'}, 
	 $self->{'bitmap_scanline_pad'}, $self->{'min_keycode'},
	 $self->{'max_keycode'}) 
	    = unpack('LLLLSSCCCCCCCCxxxx', $self->get(32));
	$self->{'bitmap_bit_order'} =
	    $self->interp('Significance', $self->{'bitmap_bit_order'});
	$self->{'image_byte_order'} =
	    $self->interp('Significance', $self->{'image_byte_order'});
	$self->{'vendor'} = substr($self->get($vlen + padding $vlen),
				   0, $vlen);
	$self->{'rsrc_shift'} = 0;
	my $mask = $self->{'resource_id_mask'};
	$self->{'rsrc_shift'}++ until ($mask >> $self->{'rsrc_shift'}) & 1;
	$self->{'rsrc_id'} = 0;
	$self->{'rsrc_base'} = $self->{'resource_id_base'};
	$self->{'rsrc_max'} = $mask;
	
	my($fmts) = $self->get(8 * $formats);
	my($n, $fmt);
	for $n (0 .. $formats - 1) {
	    $fmt = substr($fmts, 8 * $n, 8);
	    my($depth, $bpp, $pad) = unpack('CCC', $fmt);
	    $self->{'pixmap_formats'}{$depth} = {'bits_per_pixel' => $bpp,
						 'scanline_pad' => $pad};
	}

	my(@screens);
	while ($screens--) {
	    my($root_wid, $def_cmap, $w_pixel, $b_pixel, $input_masks,
	       $w_p, $h_p, $w_mm, $h_mm, $min_maps, $max_maps,
	       $root_visual, $b_store, $s_unders, $depth, $n_depths) 
		= unpack('LLLLLSSSSSSLCCCC', $self->get(40));
	    my(%s) = ('root' => $root_wid, 'width_in_pixels' => $w_p,
		      'height_in_pixels' => $h_p,
		      'width_in_millimeters' => $w_mm,
		      'height_in_millimeters' => $h_mm,
		      'root_depth' => $depth, 'root_visual' => $root_visual,
		      'default_colormap' => $def_cmap,
		      'white_pixel' => $w_pixel, 'black_pixel' => $b_pixel,
		      'min_installed_maps' => $min_maps,
		      'max_installed_maps' => $max_maps,
		      'backing_stores' =>
		         $self->interp('BackingStore', $b_store),
		      'save_unders' => $s_unders,
		      'current_input_masks' => $input_masks);
	    my($nd, @depths) = ();
	    for $nd (1 .. $n_depths) {
		my($dep, $n_visuals) = unpack('CxSxxxx', $self->get(8));
		my($nv, %vt, @visuals) = ();
		for $nv (1 .. $n_visuals) {
		    my($vid, $class, $bits_per_rgb, $map_ent, $red_mask,
		       $green_mask, $blue_mask)
			= unpack('LCCSLLLxxxx', $self->get(24));
		    $class = $self->interp('VisualClass', $class);
		    %vt = ('visual_id' => $vid, 'class' => $class,
			   'red_mask' => $red_mask,
			   'green_mask' => $green_mask,
			   'blue_mask' => $blue_mask,
			   'bits_per_rgb_value' => $bits_per_rgb,
			   'colormap_entries', => $map_ent);
		    push @visuals, {%vt};
		    delete $vt{'visual_id'};
		    $self->{'visuals'}{$vid} = {%vt, 'depth' => $dep};
		}
		push @depths, {'depth' => $dep, 'visuals' => [@visuals]};
	    }
	    $s{'allowed_depths'} = [@depths];
	    push @screens, {%s};
	}
	$self->{'screens'} = [@screens];
	$self->{'sequence_num'} = 1;
	$self->{'error_handler'} = \&default_error_handler;
	$self->{'event_handler'} = sub {};
	$self->{'requests'} = \@Requests;
	$self->{'events'} = \@Events;
	# 1 = uses rsrc/atom id field
	$self->{'error_type'} = [undef, 0, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1,
				 1, 0, 0, 0];
	$self->choose_screen($screen) if defined($screen)
	    and $screen <= $#{$self->{'screens'}};
	$self->{'do_interp'} = 1;
    } else {
	croak("Unknown response");
    }
    $self->init_extension("XC-MISC");
    return $self;
}

sub AUTOLOAD {
    my($name) = $AUTOLOAD;
    $name =~ s/^.*:://;
    return if $name eq "DESTROY"; # Avoid problems during final cleanup
    if ($name =~ /^[A-Z]/) { # Protocol request
	my($obj) = shift;

	# Make this faster next time
	no strict 'refs'; # This is slightly icky
	my($op, $major, $minor) = $obj->get_request($name);
	if (@$op == 2) { # No reply
	    *{$AUTOLOAD} = sub {
		my $self = shift;
		$self->give($self->assemble_request($op, \@_, $major, $minor));
		$self->next_sequence();
	    };
	} elsif (@$op == 3) { # One reply
	    *{$AUTOLOAD} = sub {
		my $self = shift;
		my($seq, $data);
		$self->give($self->assemble_request($op, \@_, $major, $minor));
		$seq = $self->next_sequence();
		$self->add_reply($seq & 0xffff, \$data);
		$self->handle_input_for($seq & 0xffff);
		$self->delete_reply($seq & 0xffff);
		return &{$op->[2]}($self, $data);
	    };
	} else { # ListFontsWithInfo
	    # Not worth it
	}

	return $obj->req($name, @_);
    } else { # Instance variable
	if (@_ == 1) {
	    return $_[0]->{$name};
	} elsif (@_ == 2) {
	    $_[0]->{$name} = $_[1];
	} else {
	    croak "No such function `$name'";
	}
    }
}

1;
__END__

=head1 NAME

X11::Protocol - Perl module for the X Window System Protocol, version 11

=head1 SYNOPSIS

  use X11::Protocol;
  $x = X11::Protocol->new();
  $win = $x->new_rsrc;
  $x->CreateWindow($win, $x->root, 'InputOutput',
		   $x->root_depth, 'CopyFromParent',
		   ($x_coord, $y_coord), $width,
		   $height, $border_w);  
  ...

=head1 DESCRIPTION

X11::Protocol is a client-side interface to the X11 Protocol (see X(1) for
information about X11), allowing perl programs to display windows and
graphics on X11 servers.

A full description of the protocol is beyond the scope of this documentation;
for complete information, see the I<X Window System Protocol, X Version 11>,
available as Postscript or *roff source from C<ftp://ftp.x.org>, or
I<Volume 0: X Protocol Reference Manual> of O'Reilly & Associates's series of
books about X (ISBN 1-56592-083-X, C<http://www.oreilly.com>), which contains
most of the same information.

=head1 DISCLAIMER

``The protocol contains many management mechanisms that are
not intended for normal applications.  Not all mechanisms
are needed to build a particular user interface.  It is
important to keep in mind that the protocol is intended to
provide mechanism, not policy.'' -- Robert W. Scheifler

=head1 BASIC METHODS

=head2 new

  $x = X11::Protocol->new();
  $x = X11::Protocol->new($display_name);
  $x = X11::Protocol->new($connection);
  $x = X11::Protocol->new($display_name, [$auth_type, $auth_data]);
  $x = X11::Protocol->new($connection, [$auth_type, $auth_data]);

Open a connection to a server. $display_name should be an X display
name, of the form 'host:display_num.screen_num'; if no arguments are
supplied, the contents of the DISPLAY environment variable are
used. Alternatively, a pre-opened connection, of one of the
X11::Protocol::Connection classes (see
L<X11::Protocol::Connection>,
L<X11::Protocol::Connection::FileHandle>,
L<X11::Protocol::Connection::Socket>,
L<X11::Protocol::Connection::UNIXFH>,
L<X11::Protocol::Connection::INETFH>,
L<X11::Protocol::Connection::UNIXSocket>,
L<X11::Protocol::Connection::INETSocket>) can be given. The
authorization data is obtained using X11::Auth or the second
argument. If the display is specified by $display_name, rather than
$connection, a choose_screen() is also performed, defaulting to screen
0 if the '.screen_num' of the display name is not present.  Returns
the new protocol object.

=head2 new_rsrc

  $x->new_rsrc;

Returns a new resource identifier. A unique resource ID is required
for every object that the server creates on behalf of the client:
windows, fonts, cursors, etc. (IDs are chosen by the client instead of
the server for efficiency -- the client doesn't have to wait for the
server to acknowledge the creation before starting to use the object).

Note that the total number of available resource IDs, while large, is
finite.  Beginning from the establishment of a connection, resource
IDs are allocated sequentially from a range whose size is server
dependent (commonly 2**21, about 2 million).  If this limit is reached
and the server does not support the XC_MISC extension, subsequent
calls to new_rsrc will croak.  If the server does support this
extension, the module will attempt to request a new range of free IDs
from the server.  This should allow the program to continue, but it is
an imperfect solution, as over time the set of available IDs may
fragment, requiring increasingly frequent round-trip range requests
from the server.  For long-running programs, the best approach may be
to keep track of free IDs as resources are destroyed.  In the current
version, however, no special support is provided for this.

=head2 handle_input

  $x->handle_input;

Get one chunk of information from the server, and do something with it. If it's
an error, handle it using the protocol object's handler ('error_handler'
-- default is kill the program with an explanatory message). If it's an event,
pass it to the chosen event handler, or put it in a queue if the handler is
'queue'. If it's a reply to a request, save using the object's 'replies' hash
for further processing.

=head2 atom_name

  $name = $x->atom_name($atom);

Return the string corresponding to the atom $atom. This is similar to the
GetAtomName request, but caches the result for efficiency.

=head2 atom

  $atom = $x->atom($name);

The inverse operation; Return the (numeric) atom corresponding to $name.
This is similar to the InternAtom request, but caches the result.

=head2 choose_screen

  $x->choose_screen($screen_num);

Indicate that you prefer to use a particular screen of the display. Per-screen
information, such as 'root', 'width_in_pixels', and 'white_pixel' will be
made available as 

  $x->{'root'}

instead of

  $x->{'screens'}[$screen_num]{'root'}

=head1 SYMBOLIC CONSTANTS

Generally, symbolic constants used by the protocol, like 'CopyFromParent'
or 'PieSlice' are passed to methods as strings, and
converted into numbers by the module.  Their names are the same as
those in the protocol specification, including capitalization, but
with hyphens ('-') changed to underscores ('_') to look more
perl-ish. If you want to do the conversion yourself for some reason,
the following methods are available:

=head2 num

  $num = $x->num($type, $str)

Given a string representing a constant and a string specifying what
type of constant it is, return the corresponding number. $type should
be a name like 'VisualClass' or 'GCLineStyle'. If the name is not
recognized, it is returned intact.

=head2 interp

  $name = $x->interp($type, $num)

The inverse operation; given a number and string specifying its type, return
a string representing the constant.

You can disable interp() and the module's internal interpretation of
numbers by setting $x->{'do_interp'} to zero. Of course, this isn't
very useful, unless you have you own definitions for all the
constants.

Here is a list of available constant types:

  AccessMode, AllowEventsMode, AutoRepeatMode, BackingStore,
  BitGravity, Bool, ChangePropertyMode, CirculateDirection,
  CirculatePlace, Class, ClipRectangleOrdering, CloseDownMode,
  ColormapNotifyState, CoordinateMode, CrossingNotifyDetail,
  CrossingNotifyMode, DeviceEvent, DrawDirection, Error, EventMask,
  Events, FocusDetail, FocusMode, GCArcMode, GCCapStyle, GCFillRule,
  GCFillStyle, GCFunction, GCJoinStyle, GCLineStyle, GCSubwindowMode,
  GrabStatus, HostChangeMode, HostFamily, ImageFormat,
  InputFocusRevertTo, KeyMask, LedMode, MapState, MappingChangeStatus,
  MappingNotifyRequest, PointerEvent, PolyShape, PropertyNotifyState,
  Request, ScreenSaver, ScreenSaverAction, Significance, SizeClass,
  StackMode, SyncMode, VisibilityState, VisualClass, WinGravity

=head1 SERVER INFORMATION

At connection time, the server sends a large amount of information about
itself to the client. This information is stored in the protocol object
for future reference. It can be read directly, like

  $x->{'release_number'}

or, for object oriented True Believers, using a method:

  $x->release_number

The method method also has a one argument form for setting variables, but
it isn't really useful for some of the more complex structures.

Here is an example of what the object's information might look like:

  'connection' => X11::Connection::UNIXSocket(0x814526fd),
  'byte_order' => 'l',
  'protocol_major_version' => 11,
  'protocol_minor_version' => 0,
  'authorization_protocol_name' => 'MIT-MAGIC-COOKIE-1',
  'release_number' => 3110,
  'resource_id_base' => 0x1c000002,
  'motion_buffer_size' => 0,
  'maximum_request_length' => 65535, # units of 4 bytes
  'image_byte_order' => 'LeastSiginificant',
  'bitmap_bit_order' => 'LeastSiginificant',
  'bitmap_scanline_unit' => 32,
  'bitmap_scanline_pad' => 32,
  'min_keycode' => 8,
  'max_keycode' => 134,
  'vendor' => 'The XFree86 Project, Inc',
  'pixmap_formats' => {1 => {'bits_per_pixel' => 1,
			     'scanline_pad' => 32},
                       8 => {'bits_per_pixel' => 8,
			     'scanline_pad' => 32}},
  'screens' => [{'root' => 43, 'width_in_pixels' => 800,
                 'height_in_pixels' => 600,
                 'width_in_millimeters' => 271,
                 'height_in_millimeters' => 203,
                 'root_depth' => 8,
                 'root_visual' => 34,
                 'default_colormap' => 33,
                 'white_pixel' => 0, 'black_pixel' => 1,
                 'min_installed_maps' => 1,
                 'max_installed_maps' => 1,
                 'backing_stores' => 'Always',
                 'save_unders' => 1,
                 'current_input_masks' => 0x58003d,
                 'allowed_depths' =>
                    [{'depth' => 1, 'visuals' => []},
                     {'depth' => 8, 'visuals' => [
                        {'visual_id' => 34, 'blue_mask' => 0,
                         'green_mask' => 0, 'red_mask' => 0, 
                         'class' => 'PseudoColor',
                         'bits_per_rgb_value' => 6,
                         'colormap_entries' => 256},
                        {'visual_id' => 35, 'blue_mask' => 0xc0,
                         'green_mask' => 0x38, 'red_mask' => 0x7, 
                         'class' => 'DirectColor',
                         'bits_per_rgb_value' => 6,
                         'colormap_entries' => 8}, ...]}]],
  'visuals' => {34 => {'depth' => 8, 'class' => 'PseudoColor',
                       'red_mask' => 0, 'green_mask' => 0,
                       'blue_mask'=> 0, 'bits_per_rgb_value' => 6,
                       'colormap_entries' => 256},
                35 => {'depth' => 8, 'class' => 'DirectColor',
                       'red_mask' => 0x7, 'green_mask' => 0x38,
                       'blue_mask'=> 0xc0, 'bits_per_rgb_value' => 6,
                       'colormap_entries' => 8}, ...}
  'error_handler' => &\X11::Protocol::default_error_handler,
  'event_handler' => sub {},
  'do_interp' => 1


=head1 REQUESTS

=head2 request

  $x->request('CreateWindow', ...);
  $x->req('CreateWindow', ...);
  $x->CreateWindow(...);

Send a protocol request to the server, and get the reply, if any. For
names of and information about individual requests, see below and/or
the protocol reference manual.

=head2 robust_req

  $x->robust_req('CreateWindow', ...);

Like request(), but if the server returns an error, return the error
information rather than calling the error handler (which by default
just croaks). If the request succeeds, returns an array reference
containing whatever request() would have. Otherwise, returns the error
type, the major and minor opcodes of the failed request, and the extra
error information, if any. Note that even if the request normally
wouldn't have a reply, this method still has to wait for a round-trip
time to see whether an error occurred. If you're concerned about
performance, you should design your error handling to be asynchronous.

=head2 add_reply

  $x->add_reply($sequence_num, \$var);

Add a stub for an expected reply to the object's 'replies' hash. When a reply
numbered $sequence_num comes, it will be stored in $var.

=head2 delete_reply

  $x->delete_reply($sequence_num);

Delete the entry in 'replies' for the specified reply. (This should be done
after the reply is received).

=head2 send

  $x->send('CreateWindow', ...);

Send a request, but do not wait for a reply. You must handle the reply, if any,
yourself, using add_reply(), handle_input(), delete_reply(), and
unpack_reply(), generally in that order.

=head2 unpack_reply

  $x->unpack_reply('GetWindowAttributes', $data);

Interpret the raw reply data $data, according to the reply format for the named
request. Returns data in the same format as C<request($request_name, ...)>.

This section includes only a short calling summary for each request; for
full descriptions, see the protocol standard. Argument order is usually the
same as listed in the spec, but you generally don't have to pass lengths of
strings or arrays, since perl keeps track. Symbolic constants are generally
passed as strings. Most replies are returned as lists, but when there are
many values, a hash is used. Lists usually come last; when there is more than
one, each is passed by reference. In lists of multi-part structures, each
element is a list ref. Parenthesis are inserted in arg lists for clarity,
but are optional. Requests are listed in order by major opcode, so related
requests are usually close together. Replies follow the '=>'.

  $x->CreateWindow($wid, $parent, $class, $depth, $visual, ($x, $y),
		   $width, $height, $border_width,
 		   'attribute' => $value, ...)

  $x->ChangeWindowAttributes($window, 'attribute' => $value, ...)

  $x->GetWindowAttributes($window)
  =>
  ('backing_store' => $backing_store, ...)

This is an example of a return value that is meant to be assigned to a hash.

  $x->DestroyWindow($win)

  $x->DestroySubwindows($win)

  $x->ChangeSaveSet($window, $mode)

  $x->ReparentWindow($win, $parent, ($x, $y))

  $x->MapWindow($win)

  $x->MapSubwindows($win)

  $x->UnmapWindow($win)

  $x->UnmapSubwindows($win)

  $x->ConfigureWindow($win, 'attribute' => $value, ...)

  $x->CirculateWindow($win, $direction)

Note that this request actually circulates the subwindows of $win,
not the window itself.

  $x->GetGeometry($drawable)
  =>
  ('root' => $root, ...)

  $x->QueryTree($win)
  =>
  ($root, $parent, @kids)

  $x->InternAtom($name, $only_if_exists)
  =>
  $atom

  $x->GetAtomName($atom)
  =>
  $name

  $x->ChangeProperty($window, $property, $type, $format, $mode, $data)

  $x->DeleteProperty($win, $atom)

  $x->GetProperty($window, $property, $type, $offset, $length, $delete)
  =>
  ($value, $type, $format, $bytes_after)

Notice that the value comes first, so you can easily ignore the rest.

  $x->ListProperties($window)
  =>
  (@atoms)

  $x->SetSelectionOwner($selection, $owner, $time)

  $x->GetSelectionOwner($selection)
  =>
  $owner

  $x->ConvertSelection($selection, $target, $property, $requestor, $time)

  $x->SendEvent($destination, $propagate, $event_mask, $event)

The $event argument should be the result of a pack_event() (see L<"EVENTS">)

  $x->GrabPointer($grab_window, $owner_events, $event_mask,
		  $pointer_mode, $keyboard_mode, $confine_to,
		  $cursor, $time)
  =>
  $status

  $x->UngrabPointer($time)

  $x->GrabButton($modifiers, $button, $grab_window, $owner_events,
		 $event_mask, $pointer_mode, $keyboard_mode,
		 $confine_to, $cursor)

  $x->UngrabButton($modifiers, $button, $grab_window)

  $x->ChangeActivePointerGrab($event_mask, $cursor, $time)

  $x->GrabKeyboard($grab_window, $owner_events, $pointer_mode,
		   $keyboard_mode, $time)
  =>
  $status

  $x->UngrabKeyboard($time)

  $x->GrabKey($key, $modifiers, $grab_window, $owner_events,
	      $pointer_mode, $keyboard_mode)

  $x->UngrabKey($key, $modifiers, $grab_window)

  $x->AllowEvents($mode, $time)

  $x->GrabServer

  $x->UngrabServer

  $x->QueryPointer($window)
  =>
  ('root' => $root, ...)

  $x->GetMotionEvents($start, $stop, $window)
  =>
  ([$time, ($x, $y)], [$time, ($x, $y)], ...)

  $x->TranslateCoordinates($src_window, $dst_window, $src_x, $src_y)
  =>
  ($same_screen, $child, $dst_x, $dst_y)

  $x->WarpPointer($src_window, $dst_window, $src_x, $src_y, $src_width,
		  $src_height, $dst_x, $dst_y)

  $x->SetInputFocus($focus, $revert_to, $time)

  $x->GetInputFocus
  =>
  ($focus, $revert_to)

  $x->QueryKeymap
  =>
  $keys

$keys is a bit vector, so you should use vec() to read it.

  $x->OpenFont($fid, $name)

  $x->CloseFont($font)

  $x->QueryFont($font)
  =>
  ('min_char_or_byte2' => $min_char_or_byte2,
   ..., 
   'min_bounds' =>
   [$left_side_bearing, $right_side_bearing, $character_width, $ascent,
    $descent, $attributes],
   ...,
   'char_infos' =>
   [[$left_side_bearing, $right_side_bearing, $character_width, $ascent,
     $descent, $attributes], 
    ...], 
   'properties' => {$prop => $value, ...}
   )

  $x->QueryTextExtents($font, $string)
  =>
  ('draw_direction' => $draw_direction, ...)

  $x->ListFonts($pattern, $max_names)
  =>
  @names

  $x->ListFontsWithInfo($pattern, $max_names)
  =>
  ({'name' => $name, ...}, {'name' => $name, ...}, ...)

The information in each hash is the same as the the information returned by
QueryFont, but without per-character size information. This request is
special in that it is the only request that can have more than one reply.
This means you should probably only use request() with it, not send(), as
the reply counting is complicated. Luckily, you never need this request
anyway, as its function is completely duplicated by other requests.

  $x->SetFontPath(@strings)

  $x->GetFontPath
  =>
  @strings

  $x->CreatePixmap($pixmap, $drawable, $depth, $width, $height)

  $x->FreePixmap($pixmap)

  $x->CreateGC($cid, $drawable, 'attribute' => $value, ...)

  $x->ChangeGC($gc, 'attribute' => $value, ...)

  $x->CopyGC($src, $dest, 'attribute', 'attribute', ...)

  $x->SetDashes($gc, $dash_offset, (@dashes))

  $x->SetClipRectangles($gc, ($clip_x_origin, $clip_y_origin),
			$ordering, [$x, $y, $width, $height], ...)

  $x->ClearArea($window, ($x, $y), $width, $height, $exposures)

  $x->CopyArea($src_drawable, $dst_drawable, $gc, ($src_x, $src_y),
	       $width, $height, ($dst_x, $dst_y))

  $x->CopyPlane($src_drawable, $dst_drawable, $gc, ($src_x, $src_y),
		$width, $height, ($dst_x, $dst_y), $bit_plane)

  $x->PolyPoint($drawable, $gc, $coordinate_mode,
		($x, $y), ($x, $y), ...)

  $x->PolyLine($drawable, $gc, $coordinate_mode,
	       ($x, $y), ($x, $y), ...)

  $x->PolySegment($drawable, $gc, ($x, $y) => ($x, $y),
		  ($x, $y) => ($x, $y), ...)

  $x->PolyRectangle($drawable, $gc,
		    [($x, $y), $width, $height], ...)

  $x->PolyArc($drawable, $gc,
	      [($x, $y), $width, $height, $angle1, $angle2], ...)

  $x->FillPoly($drawable, $gc, $shape, $coordinate_mode,
	       ($x, $y), ...)

  $x->PolyFillRectangle($drawable, $gc,
			[($x, $y), $width, $height], ...)

  $x->PolyFillArc($drawable, $gc,
		  [($x, $y), $width, $height, $angle1, $angle2], ...)

  $x->PutImage($drawable, $gc, $depth, $width, $height,
	       ($dst_x, $dst_y), $left_pad, $format, $data)

Currently, the module has no code to handle the various bitmap formats that
the server might specify. Therefore, this request will not work portably
without a lot of work.

  $x->GetImage($drawable, ($x, $y), $width, $height, $plane_mask,
	       $format)

  $x->PolyText8($drawable, $gc, ($x, $y),
		($font OR [$delta, $string]), ...)

  $x->PolyText16($drawable, $gc, ($x, $y),
		 ($font OR [$delta, $string]), ...)

  $x->ImageText8($drawable, $gc, ($x, $y), $string)

  $x->ImageText16($drawable, $gc, ($x, $y), $string)

  $x->CreateColormap($mid, $visual, $window, $alloc)

  $x->FreeColormap($cmap)

  $x->CopyColormapAndFree($mid, $src_cmap)

  $x->InstallColormap($cmap)

  $x->UninstallColormap($cmap)

  $x->ListInstalledColormaps($window)
  =>
  @cmaps

  $x->AllocColor($cmap, ($red, $green, $blue))
  =>
  ($pixel, ($red, $green, $blue))

  $x->AllocNamedColor($cmap, $name)
  =>
  ($pixel, ($exact_red, $exact_green, $exact_blue),
   ($visual_red, $visual_green, $visual_blue))

  $x->AllocColorCells($cmap, $colors, $planes, $contiguous)
  =>
  ([@pixels], [@masks])

  $x->AllocColorPlanes($cmap, $colors, ($reds, $greens, $blues),
		       $contiguous)
  =>
  (($red_mask, $green_mask, $blue_mask), @pixels)

  $x->FreeColors($cmap, $plane_mask, @pixels)

  $x->StoreColors($cmap, [$pixel, $red, $green, $blue, $do_mask], ...)

The 1, 2, and 4 bits in $do_mask are do-red, do-green, and
do-blue. $do_mask can be omitted, defaulting to 7, the usual case --
change the whole color.

  $x->StoreNamedColor($cmap, $pixel, $name, $do_mask)

$do_mask has the same interpretation as above, but is mandatory.

  $x->QueryColors($cmap, @pixels)
  =>
  ([$red, $green, $blue], ...)

  $x->LookupColor($cmap, $name)
  =>
  (($exact_red, $exact_green, $exact_blue),
   ($visual_red, $visual_green, $visual_blue)) 

  $x->CreateCursor($cid, $source, $mask,
		   ($fore_red, $fore_green, $fore_blue),
		   ($back_red, $back_green, $back_blue),
		   ($x, $y))

  $x->CreateGlyphCursor($cid, $source_font, $mask_font,
			$source_char, $mask_char,
			($fore_red, $fore_green, $fore_blue),
			($back_red, $back_green, $back_blue))
			
  $x->FreeCursor($cursor)

  $x->RecolorCursor($cursor, ($fore_red, $fore_green, $fore_blue),
		    ($back_red, $back_green, $back_blue))

  $x->QueryBestSize($class, $drawable, $width, $height)
  =>
  ($width, $height)

  $x->QueryExtension($name)
  =>
  ($major_opcode, $first_event, $first_error)

If the extension is not present, an empty list is returned.

  $x->ListExtensions
  =>
  (@names)

  $x->ChangeKeyboardMapping($first_keycode, $keysysms_per_keycode,
			    @keysyms)

  $x->GetKeyboardMapping($first_keycode, $count)
  =>
  ($keysysms_per_keycode, [$keysym, ...], [$keysym, ...], ...)

  $x->ChangeKeyboardControl('attribute' => $value, ...)

  $x->GetKeyboardControl
  =>
  ('global_auto_repeat' => $global_auto_repeat, ...)

  $x->Bell($percent)

  $x->ChangePointerControl($do_acceleration, $do_threshold,
			   $acceleration_numerator,
			   $acceleration_denominator, $threshold)

  $x->GetPointerControl
  =>
  ($acceleration_numerator, $acceleration_denominator, $threshold)

  $x->SetScreenSaver($timeout, $interval, $prefer_blanking,
		     $allow_exposures)

  $x->GetScreenSaver
  =>
  ($timeout, $interval, $prefer_blanking, $allow_exposures)

  $x->ChangeHosts($mode, $host_family, $host_address) 

  $x->ListHosts
  =>
  ($mode, [$family, $host], ...)

  $x->SetAccessControl($mode)

  $x->SetCloseDownMode($mode)

  $x->KillClient($resource)

  $x->RotateProperties($win, $delta, @props)

  $x->ForceScreenSaver($mode)

  $x->SetPointerMapping(@map)
  =>
  $status

  $x->GetPointerMapping
  =>
  @map

  $x->SetModifierMapping(@keycodes)
  =>
  $status

  $x->GetModiferMapping
  =>
  @keycodes

  $x->NoOperation($length)

$length specifies the length of the entire useless request, in four byte units,
and is optional.

=head1 EVENTS

To receive events, first set the 'event_mask' attribute on a window to
indicate what types of events you desire (see
L<"pack_event_mask">). Then, set the protocol object's 'event_handler'
to a subroutine reference that will handle the events. Alternatively,
set 'event_handler' to 'queue', and retrieve events using
dequeue_event() or next_event(). In both cases, events are returned as
a hash. For instance, a typical MotionNotify event might look like
this:

  %event = ('name' => 'MotionNotify', 'sequence_number' => 12,
            'state' => 0, 'event' => 58720256, 'root' => 43,
            'child' => None, 'same_screen' => 1, 'time' => 966080746,
            'detail' => 'Normal', 'event_x' => 10, 'event_y' => 3,
            'code' => 6, 'root_x' => 319, 'root_y' => 235)

=head2 pack_event_mask

  $mask = $x->pack_event_mask('ButtonPress', 'KeyPress', 'Exposure');

Make an event mask (suitable as the 'event_mask' of a window) from a list
of strings specifying event types.

=head2 unpack_event_mask

  @event_types = $x->unpack_event_mask($mask);

The inverse operation; convert an event mask obtained from the server into a
list of names of event categories.

=head2 dequeue_event

  %event = $x->dequeue_event;

If there is an event waiting in the queue, return it.

=head2 next_event

  %event = $x->next_event;

Like Xlib's XNextEvent(), this function is equivalent to

  $x->handle_input until %event = dequeue_event;

=head2 pack_event

  $data = $x->pack_event(%event);

Given an event in hash form, pack it into a string. This is only useful as
an argument to SendEvent().

=head2 unpack_event

  %event = $x->unpack_event($data);

The inverse operation; given the raw data for an event (32 bytes), unpack it
into hash form. Normally, this is done automatically.

=head1 EXTENSIONS

Protocol extensions add new requests, event types, and error types to
the protocol. Support for them is compartmentalized in modules in the
X11::Protocol::Ext:: hierarchy. For an example, see
L<X11::Protocol::Ext::SHAPE>. You can tell if the module has loaded an
extension by looking at

  $x->{'ext'}{$extension_name}

If the extension has been initialized, this value will be an array reference,
[$major_request_number, $first_event_number, $first_error_number, $obj], where
$obj is an object containing information private to the extension. 

=head2 init_extension

  $x->init_extension($name);

Initialize an extension: query the server to find the extension's request
number, then load the corresponding module. Returns 0 if the server does
not support the named extension, or if no module to interface with it exists.

=head2 init_extensions

  $x->init_extensions;

Initialize protocol extensions. This does a ListExtensions request, then calls
init_extension() for each extension that the server supports.

=head1 WRITING EXTENSIONS

Internally, the X11::Protocol module is table driven. All an extension has to
do is to add new add entries to the protocol object's tables. An extension
module should C<use X11::Protocol>, and should define an new() method

  X11::Protocol::Ext::NAME
    ->new($x, $request_num, $event_num, $error_num)

where $x is the protocol object and $request_num, $event_num and $error_num
are the values returned by QueryExtension().

The new() method should add new types of constant like

  $x->{'ext_const'}{'ConstantType'} = ['Constant', 'Constant', ...]

and set up the corresponding name to number translation hashes like

  $x->{'ext_const_num'}{'ConstantType'} =
    {make_num_hash($x->{'ext_const'}{'ConstantType'})}

Event names go in

  $x->{'ext_const'}{'Events'}[$event_number]

while specifications for event contents go in

  $x->{'ext_event'}[$event_number]

each element of which is either C<[\&unpack_sub, \&pack_sub]> or
C<[$pack_format, $field, $field, ...]>, where each $field is C<'name'>,
C<['name', 'const_type']>, or C<['name', ['special_name_for_zero',
'special_name_for_one']]>, where C<'special_name_for_one'> is optional.

Finally,

  $x->{'ext_request'}{$major_request_number}

should be an array of arrays, with each array either C<[$name, \&packit]> or
C<[$name, \&packit, \&unpackit]>, and

  $x->{'ext_request_num'}{$request_name}

should be initialized with C<[$minor_num, $major_num]> for each request the
extension defines. For examples of code that does all of this, look at
X11::Protocol::Ext::SHAPE.

X11::Protocol exports several functions that might be useful in extensions
(note that these are I<not> methods).

=head2 padding

  $p = padding $x;

Given an integer, compute the number need to round it up to a multiple of 4.
For instance, C<padding(5)> is 3.

=head2 pad

  $p = pad $str;

Given a string, return the number of extra bytes needed to make a multiple
of 4. Equivalent to C<padding(length($str))>.

=head2 padded

  $data = pack(padded($str), $str);

Return a format string, suitable for pack(), for a string padded to a multiple
of 4 bytes. For instance, C<pack(padded('Hello'), 'Hello')> gives
C<"Hello\0\0\0">.

=head2 hexi

  $str = hexi $n;

Format a number in hexidecimal, and add a "0x" to the front.

=head2 make_num_hash

  %hash = make_num_hash(['A', 'B', 'C']);

Given a reference to a list of strings, return a hash mapping the strings onto
numbers representing their position in the list, as used by
C<$x-E<gt>{'ext_const_num'}>.

=head1 BUGS

This module is too big (~2500 lines), too slow (10 sec to load on a slow
machine), too inefficient (request args are copied several times), and takes
up too much memory (3000K for basicwin).

If you have more than 65535 replies outstanding at once, sequence numbers
can collide.

The protocol is too complex.

=head1 AUTHOR

Stephen McCamant <SMCCAM@cpan.org>.

=head1 SEE ALSO

L<perl(1)>,
L<X(1)>, 
L<X11::Keysyms>, 
L<X11::Protocol::Ext::SHAPE>,
L<X11::Protocol::Ext::BIG_REQUESTS>,
L<X11::Protocol::Ext::XC_MISC>,
L<X11::Protocol::Ext::DPMS>,
L<X11::Protocol::Ext::XFree86_Misc>,
L<X11::Auth>,
I<X Window System Protocol (X Version 11)>,
I<Inter-Client Communications Conventions Manual>,
I<X Logical Font Description Conventions>.

=cut
