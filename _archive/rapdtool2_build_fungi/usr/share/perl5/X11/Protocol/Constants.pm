#!/usr/bin/perl

package X11::Protocol::Constants;

# Copyright (C) 1997, 1999, 2003 Stephen McCamant. All rights
# reserved. This program is free software; you can redistribute and/or
# modify it under the same terms as Perl itself.

use strict;
use Exporter;
use vars ('$VERSION', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS', '@ISA');
$VERSION = 0.01;
@ISA = ('Exporter');

# It seems as if the designers of the protocol started out trying to make
# all the constants distinct, got most of the way, then gave up.
# Protocol.pm has classes, and Xlib has longer names.
# There are just two bad collisions: Cap/Round vs. Join/Round and
# ALL the focus mode flags (that aren't also crossing notify ones).

my @x_dot_h =
  ('NoEventMask', 'KeyPressMask', 'KeyReleaseMask',
   'ButtonPressMask', 'ButtonReleaseMask',
   'EnterWindowMask', 'LeaveWindowMask',
   'PointerMotionMask', 'PointerMotionHintMask',
   'Button1MotionMask', 'Button2MotionMask',
   'Button3MotionMask', 'Button4MotionMask',
   'Button5MotionMask', 'ButtonMotionMask',
   'KeymapStateMask', 'ExposureMask',
   'VisibilityChangeMask', 'StructureNotifyMask',
   'ResizeRedirectMask', 'SubstructureNotifyMask',
   'SubstructureRedirectMask', 'FocusChangeMask',
   'PropertyChangeMask', 'ColormapChangeMask',
   'OwnerGrabButtonMask',

   'KeyPress' , 'KeyRelease', 'ButtonPress',
   'ButtonRelease', 'MotionNotify', 'EnterNotify',
   'LeaveNotify', 'FocusIn', 'FocusOut', 'KeymapNotify',
   'Expose', 'GraphicsExposure', 'NoExposure',
   'VisibilityNotify', 'CreateNotify', 'DestroyNotify',
   'UnmapNotify', 'MapNotify', 'MapRequest',
   'ReparentNotify', 'ConfigureNotify', 'ConfigureRequest',
   'GravityNotify', 'ResizeRequest', 'CirculateNotify',
   'CirculateRequest', 'PropertyNotify', 'SelectionClear',
   'SelectionRequest', 'SelectionNotify', 'ColormapNotify',
   'ClientMessage', 'MappingNotify', 'LASTEvent',

   'ShiftMask', 'LockMask', 'ControlMask', 'Mod1Mask',
   'Mod2Mask', 'Mod3Mask', 'Mod4Mask', 'Mod5Mask',

   'ShiftMapIndex', 'LockMapIndex', 'ControlMapIndex',
   'Mod1MapIndex', 'Mod2MapIndex', 'Mod3MapIndex',
   'Mod4MapIndex', 'Mod5MapIndex',

   'Button1Mask', 'Button2Mask', 'Button3Mask',
   'Button4Mask', 'Button5Mask',

   'Button1', 'Button2', 'Button3', 'Button4', 'Button5',

   'AnyModifier',

   'NotifyAncestor', 'NotifyVirtual', 'NotifyInferior',
   'NotifyNonlinear', 'NotifyNonlinearVirtual',
   'NotifyPointer', 'NotifyPointerRoot',
   'NotifyDetailNone',

   'VisibilityUnobscured', 'VisibilityPartiallyObscured',
   'VisibilityFullyObscured',

   'PlaceOnTop', 'PlaceOnBottom',

   'FamiliyInternet', 'FamiliyDECnet', 'FamiliyChaos',

   'PropertyNewValue', 'PropertyDeleted',

   'ColormapUninstalled', 'ColormapInstalled',

   'GrabModeSync', 'GrabModeAsync',

   'GrabSuccess', 'GrabInvalidTime', 'GrabNotViewable',
   'GrabFrozen', 'AlreadyGrabbed',

   'AsyncPointer', 'SyncPointer', 'ReplayPointer',
   'AsyncKeyboard', 'SyncKeyboard', 'ReplayKeyboard',
   'AsyncBoth', 'SyncBoth',

   'RevertToNone', 'RevertToPointerRoot', 'RevertToParent',

   'BadRequest', 'BadValue', 'BadWindow', 'BadPixmap',
   'BadAtom', 'BadCursor', 'BadFont', 'BadMatch',
   'BadDrawable', 'BadAccess', 'BadAlloc', 'BadColormap',
   'BadGC', 'BadIDChoice', 'BadName', 'BadLength',
   'BadImplementation',

   'FirstExtensionError', 'LastExtensionError',

   'CopyFromParent', 'InputOutput', 'InputOnly',

   'ForgetGravity', 'StaticGravity', 'NorthWestGravity',
   'NorthGravity', 'NorthEastGravity', 'WestGravity',
   'CenterGravity', 'EastGravity', 'SouthWestGravity',
   'SouthGravity', 'SouthEastGravity', 'UnmapGravity',

   'WhenMapped', 'Always',

   'NotUseful',

   'IsUnmapped', 'IsUnviewable', 'IsViewable',

   'SetModeInsert', 'SetModeDelete',

   'RetainPermanent', 'RetainTemporary',

   'DestroyAll',

   'Above', 'Below', 'TopIf', 'BottomIf', 'Opposite',

   'RaiseLowest', 'LowerHighest',

   'PropModeReplace', 'PropModePrepend', 'PropModeAppend',

   'GXclear', 'GXand', 'GXandReverse', 'GXcopy',
   'GXandInverted', 'GXnoop', 'GXxor', 'GXor', 'GXnor',
   'GXequiv', 'GXinvert', 'GXorReverse', 'GXcopyInverted',
   'GXorInverted', 'GXnand', 'GXset',

   'LineSolid', 'LineOnOffDash', 'LineDoubleDash',

   'CapNotLast', 'CapButt', 'CapRound', 'CapProjecting',

   'JoinMiter', 'JoinRound', 'JoinBevel',

   'FillSolid', 'FillTiled', 'FillStippled',
   'FillOpaqueStippled',

   'EvenOddRule', 'WindingRule',

   'ClipByChildren', 'IncludeInferiors',

   'YSorted', 'YXSorted', 'YXBanded',
   'Unsorted',

   'CoordModeOrigin', 'CoordModePrevious',

   'Complex', 'Nonconvex', 'Convex',

   'ArcChord', 'ArcPieSlice',

   'FontLeftToRight', 'FontRightToLeft',

   'FontChange',

   'XYPixmap', 'ZPixmap', 'XYBitmap',

   'AllocNone', 'AllocAll',

   'DoRed', 'DoGreen', 'DoBlue',

   'CursorShape', 'TileShape', 'StippleShape',

   'AutoRepeatModeOff', 'AutoRepeatModeOn',
   'AutoRepeatModeDefault',

   'LedModeOff', 'LedModeOn',

   'MappingModifier', 'MappingKeyboard', 'MappingPointer',

   'MappingSuccess', 'MappingBusy', 'MappingFailed',

   'DontPreferBlanking', 'PreferBlanking', 'DefaultBlanking',
   'DisableScreenSaver', 'DisableScreenInterval',
   'DontAllowExposures', 'AllowExposures', 'DefaultExposures',

   'ScreenSaverReset', 'ScreenSaverActive',

   'HostInsert', 'HostDelete',

   'DisableAccess', 'EnableAccess',

   'StaticGray', 'GrayScale', 'StaticColor',
   'PseudoColor', 'TrueColor', 'DirectColor',

   'GreyScale', 'StaticGrey', 'StaticColour',
   'PseudoColour', 'TrueColour', 'DirectColour',

   'LSBFirst', 'MSBFirst');

my @protocol =
  (
   'StaticGray', 'GrayScale', 'StaticColor',
   'PseudoColor', 'TrueColor', 'DirectColor',

   'GreyScale', 'StaticGrey', 'StaticColour',
   'PseudoColour', 'TrueColour', 'DirectColour',

   'Forget', 'Static', 'NorthWest', 'North',
   'NorthEast', 'West', 'Center', 'East',
   'SouthWest', 'South', 'SouthEast', 'Unmap',

   'KeyPress', 'KeyRelease', 'ButtonPress', 'ButtonRelease',
   'EnterWindow', 'LeaveWindow', 'PointerMotion',
   'PointerMotionHint', 'Button1Motion', 'Button2Motion',
   'Button3Motion', 'Button4Motion', 'Button5Motion',
   'ButtonMotion', 'KeymapState', 'Exposure',
   'VisibilityChange', 'StructureNotify', 'ResizeRedirect',
   'SubstructureNotify', 'SubstructureRedirect',
   'FocusChange', 'PropertyChange', 'ColormapChange',
   'OwnerGrabButton',

   'MotionNotify', 'EnterNotify',
   'LeaveNotify', 'FocusIn', 'FocusOut', 'KeymapNotify',
   'Expose', 'GraphicsExposure', 'NoExposure',
   'VisibilityNotify', 'CreateNotify', 'DestroyNotify',
   'UnmapNotify', 'MapNotify', 'MapRequest',
   'ReparentNotify', 'ConfigureNotify', 'ConfigureRequest',
   'GravityNotify', 'ResizeRequest', 'CirculateNotify',
   'CirculateRequest', 'PropertyNotify', 'SelectionClear',
   'SelectionRequest', 'SelectionNotify',
   'ColormapNotify', 'ClientMessage', 'MappingNotify',

   'Shift', 'Lock', 'Control', 'Mod1', 'Mod2', 'Mod3',
   'Mod4', 'Mod5',

   'LeastSignificant', 'MostSignificant',

   'Never', 'WhenMapped', 'Always',

   'False', 'True',

   'CopyFromParent', 'InputOutput', 'InputOnly',

   'Unmapped', 'Unviewable', 'Viewable',

   'Above', 'Below', 'TopIf', 'BottomIf', 'Opposite',

   'RaiseLowest', 'LowerHighest',

   'Replace', 'Prepend', 'Append',

   'Ancestor', 'Virtual', 'Inferior', 'Nonlinear',
   'NonlinearVirtual',

   'Normal', 'Grab', 'Ungrab', 'WhileGrabbed',

   'Unobscured', 'PartiallyObscured', 'FullyObscured',

   'Top', 'Bottom',

   'NewValue', 'Deleted',

   'Uninstalled', 'Installed',

   'Modifier', 'Keyboard', 'Pointer',

   'Synchronous', 'Asynchronous',

   'Success', 'AlreadyGrabbed', 'InvalidTime',
   'NotViewable', 'Frozen',

   'AsyncPointer', 'SyncPointer', 'ReplayPointer',
   'AsyncKeyboard', 'SyncKeyboard',
   'ReplayKeyboard', 'AsyncBoth', 'SyncBoth',

   'None', 'PointerRoot', 'Parent',

   'LeftToRight', 'RightToLeft',

   'UnSorted', 'YSorted', 'YXSorted', 'YXBanded',

   'Origin', 'Previous',

   'Complex', 'Nonconvex', 'Convex',

   'Bitmap', 'XYPixmap', 'ZPixmap',

   'Cursor', 'Tile', 'Stipple',

   'Off', 'On', 'Default',

   'No', 'Yes', 'Default',

   'Insert', 'Delete',

   'Internet', 'DECnet', 'Chaos',

   'Disabled', 'Enabled',

   'Destroy', 'RetainPermanent', 'RetainTemporary',

   'Reset', 'Activate',

   'Success', 'Busy', 'Failed',

   'Clear', 'And', 'AndReverse', 'Copy',
   'AndInverted', 'NoOp', 'Xor', 'Or', 'Nor', 'Equiv',
   'Invert', 'OrReverse', 'CopyInverted', 'OrInverted',
   'Nand', 'Set',

   'Solid', 'OnOffDash', 'DoubleDash',

   'NotLast', 'Butt', 'Round', 'Projecting',

   'Miter', 'Round', 'Bevel',

   'Solid', 'Tiled', 'Stippled', 'OpaqueStippled',

   'EvenOdd', 'Winding',

   'ClipByChildren', 'IncludeInferiors',

   'Chord', 'PieSlice');

my @masks =
  (	
   'KeyPress_mask', 'KeyRelease_mask', 'ButtonPress_mask',
   'ButtonRelease_mask', 'EnterWindow_mask',
   'LeaveWindow_mask', 'PointerMotion_mask',
   'PointerMotionHint_mask', 'Button1Motion_mask',
   'Button2Motion_mask', 'Button3Motion_mask',
   'Button4Motion_mask', 'Button5Motion_mask',
   'ButtonMotion_mask', 'KeymapState_mask',
   'Exposure_mask', 'VisibilityChange_mask',
   'StructureNotify_mask', 'ResizeRedirect_mask',
   'SubstructureNotify_mask', 'SubstructureRedirect_mask',
   'FocusChange_mask', 'PropertyChange_mask',
   'ColormapChange_mask', 'OwnerGrabButton_mask',
  );

my @masks_m =
  (
   'KeyPress_m', 'KeyRelease_m', 'ButtonPress_m',
   'ButtonRelease_m', 'EnterWindow_m', 'LeaveWindow_m',
   'PointerMotion_m', 'PointerMotionHint_m',
   'Button1Motion_m', 'Button2Motion_m', 'Button3Motion_m',
   'Button4Motion_m', 'Button5Motion_m', 'ButtonMotion_m',
   'KeymapState_m', 'Exposure_m', 'VisibilityChange_m',
   'StructureNotify_m', 'ResizeRedirect_m',
   'SubstructureNotify_m', 'SubstructureRedirect_m',
   'FocusChange_m', 'PropertyChange_m', 'ColormapChange_m',
   'OwnerGrabButton_m',
  );

my @disambig =
  (
   'PointerDetail', 'PointerRootDetail', 'NoDetail',

   'NotifyNormal', 'NotifyGrab', 'NotifyUngrab',
   'NotifyWhileGrabbed', 'NotifyHint',

   'RoundCap', 'RoundJoin',
  );

%EXPORT_TAGS = ('X_dot_h' => \@x_dot_h,
		'Protocol' => \@protocol,
		'Masks' => \@masks,
		'Masks_m' => \@masks_m,
		'Disambiguate' => \@disambig);

Exporter::export_ok_tags(keys %EXPORT_TAGS);

{
    my %seen;
    push @{$EXPORT_TAGS{all}},
      grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}} foreach keys %EXPORT_TAGS;
}


# VisualClass
sub StaticGray () { 0 }
sub StaticGrey () { 0 }
sub GrayScale () { 1 }
sub GreyScale () { 1 }
sub StaticColor () { 2 }
sub StaticColour () { 2 }
sub PseudoColor () { 3 }
sub PseudoColour () { 3 }
sub TrueColor () { 4 }
sub TrueColour () { 4 }
sub DirectColor () { 5 }
sub DirectColour () { 5 }

# (Bit|Win)Gravity
sub Forget () { 0 }
sub Unmap () { 0 }
sub Static () { 1 }
sub NorthWest () { 2 }
sub North () { 3 }
sub NorthEast () { 4 }
sub West () { 5 }
sub Center () { 6 }
sub East () { 7 }
sub SouthWest () { 8 }
sub South () { 9 }
sub SouthEast () { 10 }

sub ForgetGravity () { 0 }
sub UnmapGravity () { 0 }
sub StaticGravity () { 1 }
sub NorthWestGravity () { 2 }
sub NorthGravity () { 3 }
sub NorthEastGravity () { 4 }
sub WestGravity () { 5 }
sub CenterGravity () { 6 }
sub EastGravity () { 7 }
sub SouthWestGravity () { 8 }
sub SouthGravity () { 9 }
sub SouthEastGravity () { 10 }

# EventMask
sub KeyPress_m () { 1 }
sub KeyRelease_m () { 2 }
sub ButtonPress_m () { 4 }
sub ButtonRelease_m () { 8 }
sub EnterWindow_m () { 16 }
sub LeaveWindow_m () { 32 }
sub PointerMotion_m () { 64 }
sub PointerMotionHint_m () { 128 }
sub Button1Motion_m () { 256 }
sub Button2Motion_m () { 512 }
sub Button3Motion_m () { 1024 }
sub Button4Motion_m () { 2048 }
sub Button5Motion_m () { 4096 }
sub ButtonMotion_m () { 8192 }
sub KeymapState_m () { 16384 }
sub Exposure_m () { 32768 }
sub VisibilityChange_m () { 65536 } # As far as I can go in my head.
sub StructureNotify_m () { 131072 } # Luckily, perl can compute these at
sub ResizeRedirect_m () { 1<<18 } # compile time.
sub SubstructureNotify_m () { 1<<19 }
sub SubstructureRedirect_m () { 1<<20 }
sub FocusChange_m () { 1<<21 }
sub PropertyChange_m () { 1<<22 }
sub ColormapChange_m () { 1<<23 }
sub OwnerGrabButton_m () { 1<<24 }

sub KeyPress_mask () { 1 }
sub KeyRelease_mask () { 2 }
sub ButtonPress_mask () { 4 }
sub ButtonRelease_mask () { 8 }
sub EnterWindow_mask () { 16 }
sub LeaveWindow_mask () { 32 }
sub PointerMotion_mask () { 64 }
sub PointerMotionHint_mask () { 128 }
sub Button1Motion_mask () { 256 }
sub Button2Motion_mask () { 512 }
sub Button3Motion_mask () { 1024 }
sub Button4Motion_mask () { 2048 }
sub Button5Motion_mask () { 4096 }
sub ButtonMotion_mask () { 8192 }
sub KeymapState_mask () { 16384 }
sub Exposure_mask () { 32768 }
sub VisibilityChange_mask () { 65536 }
sub StructureNotify_mask () { 1<<17 }
sub ResizeRedirect_mask () { 1<<18 }
sub SubstructureNotify_mask () { 1<<19 }
sub SubstructureRedirect_mask () { 1<<20 }
sub FocusChange_mask () { 1<<21 }
sub PropertyChange_mask () { 1<<22 }
sub ColormapChange_mask () { 1<<23 }
sub OwnerGrabButton_mask () { 1<<24 }

sub NoEventMask () { 0 } # Xlib
sub KeyPressMask () { 1 }
sub KeyReleaseMask () { 2 }
sub ButtonPressMask () { 4 }
sub ButtonReleaseMask () { 8 }
sub EnterWindowMask () { 16 }
sub LeaveWindowMask () { 32 }
sub PointerMotionMask () { 64 }
sub PointerMotionHintMask () { 128 }
sub Button1MotionMask () { 256 }
sub Button2MotionMask () { 512 }
sub Button3MotionMask () { 1024 }
sub Button4MotionMask () { 2048 }
sub Button5MotionMask () { 4096 }
sub ButtonMotionMask () { 8192 }
sub KeymapStateMask () { 16384 }
sub ExposureMask () { 32768 }
sub VisibilityChangeMask () { 65536 }
sub StructureNotifyMask () { 1<<17 }
sub ResizeRedirectMask () { 1<<18 }
sub SubstructureNotifyMask () { 1<<19 }
sub SubstructureRedirectMask () { 1<<20 }
sub FocusChangeMask () { 1<<21 }
sub PropertyChangeMask () { 1<<22 }
sub ColormapChangeMask () { 1<<23 }
sub OwnerGrabButtonMask () { 1<<24 }


# Plain old Events
sub KeyPress () { 2 }
sub KeyRelease () { 3 }
sub ButtonPress () { 4 }
sub ButtonRelease () { 5 }
sub MotionNotify () { 6 }
sub EnterWindow () { 7 }
sub LeaveWindow () { 8 }
sub FocusIn () { 9 }
sub FocusOut () { 10 }
sub KeymapNotify () { 11 }
sub Expose () { 12 }
sub GraphicsExposure () { 13 }
sub NoExposure () { 14 }
sub VisibilityNotify () { 15 }
sub CreateNotify () { 16 }
sub DestroyNotify () { 17 }
sub UnmapNotify () { 18 }
sub MapNotify () { 19 }
sub MapRequest () { 20 }
sub ReparentNotify () { 21 }
sub ConfigureNotify () { 22 }
sub ConfigureRequest () { 23 }
sub GravityNotify () { 24 }
sub ResizeRequest () { 25 }
sub CirculateNotify () { 26 }
sub CirculateRequest () { 27 }
sub PropertyNotify () { 28 }
sub SelectionClear () { 29 }
sub SelectionRequest () { 30 }
sub SelectionNotify () { 31 }
sub ColormapNotify () { 32 }
sub ClientMessage () { 33 }
sub MappingNotify () { 34 }
sub LASTEvent () { 35 } # Xlib

# KeyMasks
sub Shift () { 1 }
sub Lock () { 2 }
sub Control () { 4 }
sub Mod1 () { 8 }
sub Mod2 () { 16 }
sub Mod3 () { 32 }
sub Mod4 () { 64 }
sub Mod5 () { 128 }

sub ShiftMask () { 1 }
sub LockMask () { 2 }
sub ControlMask () { 4 }
sub Mod1Mask () { 8 }
sub Mod2Mask () { 16 }
sub Mod3Mask () { 32 }
sub Mod4Mask () { 64 }
sub Mod5Mask () { 128 }

sub ShiftMapIndex () { 0 }
sub LockMapIndex () { 1 }
sub ControlMapIndex () { 2 }
sub Mod1MapIndex () { 3 }
sub Mod2MapIndex () { 4 }
sub Mod3MapIndex () { 5 }
sub Mod4MapIndex () { 6 }
sub Mod5MapIndex () { 7 }

# Button masks
sub Button1Mask () { 256 }
sub Button2Mask () { 512 }
sub Button3Mask () { 1024 }
sub Button4Mask () { 2048 }
sub Button5Mask () { 4096 }

sub AnyModifier () { 1<<15 }

# Button names. Dubious value.
sub Button1 () { 1 }
sub Button2 () { 2 }
sub Button3 () { 3 }
sub Button4 () { 4 }
sub Button5 () { 5 }

# Significance
sub LeastSignificant () { 0 }
sub MostSignificant () { 1 }

sub LSBFirst () { 0 }
sub MSBFirst () { 1 }

# BackingStore
sub Never () { 0 }
sub WhenMapped () { 1 }
sub Always () { 2 }

sub NotUseful () { 0 }

# Booleans
sub False () { 0 }
sub True () { 1 }

# Window Classes
sub CopyFromParent () { 0 }
sub InputOutput () { 1 } # Bad hash collision between this
sub InputOnly () { 2 } # and this. (IO). Oh well.

# MapStates
sub Unmapped () { 0 }
sub Unviewable () { 1 }
sub Viewable () { 2 }

sub IsUnmapped () { 0 }
sub IsUnviewable () { 1 }
sub IsViewable () { 2 }

# StackModes
sub Above () { 0 }
sub Below () { 1 }
sub TopIf () { 2 }
sub BottomIf () { 3 }
sub Opposite () { 4 }

# CirculateDirections
sub RaiseLowest () { 0 }
sub LowerHighest () { 1 }

# Circulation requests
sub PlaceOnTop () { 0 }
sub PlaceOnBottom () { 1 }

# PropertyChangeModes
sub Replace () { 0 }
sub Prepend () { 1 }
sub Append () { 2 }

sub PropModeReplace () { 0 }
sub PropModePrepend () { 1 }
sub PropModeAppend () { 2 }

# CrossingNotifyDetails
sub Ancestor () { 0 }
sub Virtual () { 1 }
sub Inferior () { 2 }
sub Nonlinear () { 3 }
sub NonlinearVirtual () { 4 }
# ... and FocusDetails
sub PointerDetail () { 5 } # uh-oh
sub PointerRootDetail () { 6 } # "
sub NoDetail () { 7 } # "

sub NotifyAncestor () { 0 }
sub NotifyVirtual () { 1 }
sub NotifyInferior () { 2 }
sub NotifyNonlinear () { 3 }
sub NotifyNonlinearVirtual () { 4 }
sub NotifyPointerl () { 5 }
sub NotifyPointerRoot () { 6 }
sub NotifyDetailNone () { 7 }

# CrossingNotifyModes
sub Normal () { 0 }
sub Grab () { 1 }
sub Ungrab () { 2 }
# ... and FocusModes
sub WhileGrabbed () { 3 }

sub NotifyNormal () { 0 }
sub NotifyGrab () { 1 }
sub NotifyUngrab () { 2 }
sub NotifyWhileGrabbed () { 3 }

sub NotifyHint () { 1 }

# VisibilityStates
sub Unobscured () { 0 }
sub PartiallyObscured () { 1 }
sub FullyObscured () { 2 }

sub VisibilityUnobscured () { 0 }
sub VisibilityPartiallyObscured () { 1 }
sub VisibilityFullyObscured () { 2 }

# CirculatePlaces
sub Top () { 0 }
sub Bottom () { 1 }

# PropertyNotifyStates
sub NewValue () { 0 }
sub Deleted () { 1 }

sub PropertyNewValue () { 0 }
sub PropertyDeleted () { 1 }

# ColormapNotifyStates
sub Uninstalled () { 0 }
sub Installed () { 1 }

sub ColormapUninstalled () { 0 }
sub ColormapInstalled () { 1 }

# MappingNotifyRequests
sub Modifier () { 0 }
sub Keyboard () { 1 }
sub Pointer () { 2 }

sub MappingModifier () { 0 }
sub MappingKeyboard () { 1 }
sub MappingPointer () { 2 }

# Synchroni(city|zation)Modes
sub Synchronous () { 0 }
sub Asynchronous () { 1 }

sub GrabModeSync () { 0 }
sub GrabModeAsync () { 1 }

# GrabStatuses
sub Success () { 0 }
sub AlreadyGrabbed () { 1 }
sub InvalidTime () { 2 }
sub NotViewable () { 3 }
sub Frozen () { 4 }

sub GrabSuccess () { 0 }
# No `GrabAlreadyGrabbed'
sub GrabInvalidTime () { 2 }
sub GrabNotViewable () { 3 }
sub GrabFrozen () { 4 }

# AllowEventsModes
sub AsyncPointer () { 0 }
sub SyncPointer () { 1 }
sub ReplayPointer () { 2 }
sub AsyncKeyboard () { 3 }
sub SyncKeyboard () { 4 }
sub ReplayKeyboard () { 5 }
sub AsyncBoth () { 6 }
sub SyncBoth () { 7 }

# InputFocusRevertTos
sub None () { 0 }
sub PointerRoot () { 1 }
sub Parent () { 2 }

sub RevertToNone () { 0 }
sub RevertToPointerRoot () { 1 }
sub RevertToParent () { 2 }

# DrawDirections
sub LeftToRight () { 0 }
sub RightToLeft () { 1 }

sub FontLeftToRight () { 0 }
sub FontRightToLeft () { 1 }

sub FrontChange () { 255 }

# ClipRectangleOrderings
sub UnSorted () { 0 } # The capitalization of `Un' things is inconsistent 
sub Unsorted () { 0 } # in these constants. Xlib gets it `right'.
sub YSorted () { 1 } 
sub YXSorted () { 2 }
sub YXBanded () { 3 }

# CoordinateModes
sub Origin () { 0 }
sub Previous () { 1 }

sub CoordModeOrigin () { 0 }
sub CoordModePrevious () { 1 }

# PolyShapes
sub Complex () { 0 }
sub Nonconvex () { 1 }
sub Convex () { 2 }

# ImageFormats
sub Bitmap () { 0 }
sub XYPixmap () { 1 }
sub ZPixmap () { 2 }

sub XYBitmap () { 0 }

# SizeClasses
sub Cursor () { 0 }
sub Tile () { 1 }
sub Stipple () { 2 }

sub CursorShape () { 0 }
sub TileShape () { 1 }
sub StippleShape () { 2 }

# LedModes
sub Off () { 0 }
sub On () { 1 }
# ... and AutoRepeatModes
sub Default () { 2 }

sub AutoRepeatModeOff () { 0 }
sub AutoRepeatModeOn () { 1 }
sub AutoRepeatModeDefault () { 2 }

sub LedModeOff () { 0 }
sub LedModeOn () { 1 }

# ScreenSaver modes
sub No () { 0 }
sub Yes () { 1 }
# sub Default () { 2 }

# HostChangeModes
sub Insert () { 0 }
sub Delete () { 1 }

sub SetModeInsert () { 0 }
sub SetModeDelete () { 1 }

sub HostInsert () { 0 }
sub HostDelete () { 1 }

# HostFamilies
sub Internet () { 0 }
sub DECnet () { 1 } # slightly obscure
sub Chaos () { 2 } # really obscure

sub FamilyInternet () { 0 }
sub FamilyDECnet () { 1 }
sub FamilyChaos () { 2 }

# AccessModes
sub Disabled () { 0 }
sub Enabled () { 1 }

sub DisableAccess () { 0 }
sub EnableAccess () { 1 }

# CloseDownModes
sub Destroy () { 0 }
sub RetainPermanent () { 1 }
sub RetainTemporary () { 2 }

sub DestroyAll () { 0 }

# ScreenSaverActions
sub Reset () { 0 }
sub Activate () { 1 }

# MappingChangeStatuses
# sub Success () { 0 }
sub Busy () { 1 }
sub Failed () { 2 }

sub MappingSuccess () { 0 }
sub MappingBusy () { 1 }
sub MappingFailed () { 2 }

#        dest
#    \  0   1
#     ---------
# s 0 | 8 | 4 |
# r   ---------
# c 1 | 2 | 1 |
#     ---------
# GC Functions
sub Clear () { 0 } # Yes, we have all 16 logically possible functions.
sub And () { 1 } 
sub AndReverse () { 2 } # When was the last time you used this?
sub Copy () { 3 }
sub AndInverted () { 4 } # or this?
sub NoOp () { 5 } # or this???
sub Xor () { 6 } # This one sounds useful...
sub Or () { 7 }
sub Nor () { 8 }
sub Equiv () { 9 }
sub Invert () { 10 }
sub OrReverse () { 11 }
sub CopyInverted () { 12 }
sub OrInverted () { 13 }
sub Nand () { 14 }
sub Set () { 15 }

sub GXclear () { 0 }
sub GXand () { 1 } 
sub GXandReverse () { 2 }
sub GXcopy () { 3 }
sub GXandInverted () { 4 }
sub GXnoop () { 5 }
sub GXxor () { 6 }
sub GXor () { 7 }
sub GXnor () { 8 }
sub GXequiv () { 9 }
sub GXinvert () { 10 }
sub GXorReverse () { 11 }
sub GXcopyInverted () { 12 }
sub GXorInverted () { 13 }
sub GXnand () { 14 }
sub GXset () { 15 }

# GC LineStyles
sub Solid () { 0 }
sub OnOffDash () { 1 }
sub DoubleDash () { 2 }

sub LineSolid () { 0 }
sub LineOnOffDash () { 1 }
sub LineDoubleDash () { 2 }

# GC CapStyles
sub NotLast () { 0 }
sub Butt () { 1 }
sub RoundCap () { 2 } # @#!$ protocol designers...
sub Projecting () { 3 }

sub CapNotLast () { 0 }
sub CapButt () { 1 }
sub CapRound () { 2 }
sub CapProjecting () { 3 }

# GC JoinStyles
sub Miter () { 0 }
sub RoundJoin () { 1 } # right next to each other!
sub Bevel () { 2 }

sub JoinMiter () { 0 }
sub JoinRound () { 1 }
sub JoinBevel () { 2 }

# GC FillStyles
#sub Solid () { 0 }
sub Tiled () { 1 }
sub Stippled () { 2 }
sub OpaqueStippled () { 3 }

sub FillSolid () { 0 }
sub FillTiled () { 1 }
sub FillStippled () { 2 }
sub FillOpaqueStippled () { 3 }

# GC FillRules
sub EvenOdd () { 0 }
sub Winding () { 1 }

sub EvenOddRule () { 0 }
sub WindingRule () { 1 }

# GC SubwindowModes
sub ClipByChildren () { 0 }
sub IncludeInferiors () { 1 }

# GC ArcModes
sub Chord () { 0 }
sub PieSlice () { 1 }

sub ArcChord () { 0 }
sub ArcPieSlice () { 1 }

sub BadRequest () { 1 }
sub BadValue () { 2 }
sub BadWindow () { 3 }
sub BadPixmap () { 4 }
sub BadAtom () { 5 }
sub BadCursor () { 6 }
sub BadFont () { 7 }
sub BadMatch () { 8 }
sub BadDrawable () { 9 }
sub BadAccess () { 10 }
sub BadAlloc () { 11 }
sub BadColormap () { 12 }
sub BadGC () { 13 }
sub BadIDChoice () { 14 }
sub BadName () { 15 }
sub BadLength () { 16 }
sub BadImplementation () { 17 }

sub FirstExtensionError () { 128 }
sub LastExtensionError () { 255 }

# Colormap allocation styles
sub AllocNone () { 0 }
sub AllocAll () { 1 }

# Color storage flags
sub DoRed () { 1 }
sub DoGreen () { 2 }
sub DoBlue () { 4 }

# `SCREEN SAVER STUFF'
sub DontPreferBlanking () { 0 }
sub PreferBlanking () { 1 }
sub DefaultBlanking () { 2 }

sub DisableScreenSaver () { 0 }
sub DisableScreenInterval () { 0 }

sub DontAllowExposures () { 0 }
sub AllowExposures () { 1 }
sub DefaultExposures () { 2 }

1;
