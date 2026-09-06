#!/usr/bin/perl

package X11::Protocol::Ext::XFree86_Misc; # XFree86-Misc Extension

# This module was originally written in 1998 by Jay Kominek.  As of
# February 10th, 2003, he has placed it in the public domain.

use X11::Protocol qw(pad padding padded make_num_hash);
use Carp;

use strict;
use vars '$VERSION';

$VERSION = 0.01;

sub new {
  my($pkg, $x, $request_num, $event_num, $error_num) = @_;
  my($self) = { };

  my(@tmp) = ('MICROSOFT','MOUSESYS','MMSERIES','LOGITECH','BUSMOUSE',
	      'PS/2','MMHIT','GLIDEPOINT','IMSERIAL','THINKING',
	      'IMPS2','THINKINGPS2','MMANPLUSPS2','GLIDEPOINTPS2',
	      'NETPS2','NETSCROLLPS2','SYSMOUSE','AUTOMOSE');
  @tmp[127..128] = ('XQUEUE','OSMOUSE');

  # Constants
  $x->{'ext_const'}{'MouseTypes'} = [@tmp];
  $x->{'ext_const_num'}{'MouseTypes'} =
    {make_num_hash($x->{'ext_const'}{'MouseTypes'})};

  $x->{'ext_const'}{'KeyboardTypes'} = ['Unknown','84 Key','101 Key',
					'Other', 'XQUEUE'];
  $x->{'ext_const_num'}{'KeyboardTypes'} =
    {make_num_hash($x->{'ext_const'}{'KeyboardTypes'})};

  my(@tmp); @tmp[1,2,128] = ('Clear DTR','Clear RTS','Reopen');
  $x->{'ext_const'}{'MouseFlags'} = [@tmp];
  $x->{'ext_const_num'}{'MouseFlags'} =
    {make_num_hash($x->{'ext_const'}{'MouseFlags'})};

  # Events

  # Requests
  $x->{'ext_request'}{$request_num} =
    [
     ["XF86MiscQueryVersion", sub {
	my($self) = shift;
	return "";
      }, sub {
	my($self) = shift;
	my($data) = @_;
	my($major,$minor) = unpack("xxxxxxxxSSxxxxxxxxxxxxxxxxxxxx",$data);
        return($major,$minor);
      }],
     ["XF86MiscGetSaver", sub {
	my($self) = shift;
	my($screen) = @_;
	return pack("Sxx",$screen);
      }, sub {
	my($self) = shift;
	my($data) = @_;
	my($suspend,$off) = unpack("xxxxxxxxLLxxxxxxxxxxxxxxxx",$data);
	return($suspend,$off);
      }],
     ["XF86MiscSetSaver", sub {
	my($self) = shift;
	my($screen,$suspend,$off) = @_;
	return pack("SxxLL",$screen,$suspend,$off);
      }],
     ["XF86MiscGetMouseSettings", sub {
	return "";
      }, sub {
	my($self) = shift;
	my($data) = @_;
	my($type,$baudrate,$samplerate,$resolution,$buttons,
	   $emulate3,$chord,$emulate3timeout,$flags,$devnamelen)
	  = unpack("xxxxxxxxLLLLLCCxxLLL",$data);
	return(mousetype=>$self->interp('MouseTypes',$type),
	       baudrate=>$baudrate,samplerate=>$samplerate,
	       resolution=>$resolution,buttons=>$buttons,
	       emulate3buttons=>$emulate3,chordmiddle=>$chord,
	       emulate3timeout=>$emulate3timeout,flags=>$flags,
	       device=>substr($data,44,$devnamelen-1));
      }],
     ["XF86MiscGetKbdSettings", sub {
	return "";
      }, sub {
	my($self) = shift;
	my($data) = @_;
	my($type,$rate,$delay,$servnumlock) =
	  unpack("xxxxxxxxLLLCxxxxxxxxxxxx",$data);
	return($type,$rate,$delay,$servnumlock);
      }],
     ["XF86MiscSetMouseSettings", sub {
	my($self) = shift;
	my(%args) = @_;
	return pack("LLLLLCCxxLL",$self->pack('MouseTypes',$args{mousetype}),
		    $args{baudrate},$args{samplerate},$args{resolution},
		    $args{buttons},$args{emulate3buttons},$args{chordmiddle},
		    $args{emulate3timeout},$args{flags});
      }],
     ["XF86MiscSetKbdSettings", sub {
	my($self) = shift;
	my($type,$rate,$delay,$servnumlock) = @_;
	return pack("LLLCxxx",$self->pack('KeyboardTypes',$type),
		    $rate,$delay,$servnumlock);
      }]
    ];

  my($i);
  for $i (0..$#{$x->{'ext_request'}{$request_num}}) {
    $x->{'ext_request_num'}{$x->{'ext_request'}{$request_num}[$i][0]}
      = [$request_num, $i];
  }
  ($self->{'major'}, $self->{'minor'}) = $x->req('XF86MiscQueryVersion');
  return(bless $self, $pkg);
}

1;
__END__

=head1 NAME

X11::Protocol::Ext::XFree86_Misc.pm - Perl module for the XFree86 Misc Extension

=head1 SYNOPSIS

  use X11::Protocol;
  $x = X11::Protocol->new();
  $x->init_extension('XFree86-Misc');

=head1 DESCRIPTION

This module is used to access miscellaneous features of XFree86 servers

=head1 SYMBOLIC CONSTANTS

This extension adds the MouseTypes, KeyboardTypes and MouseFlags constants,
with values as defined in the XFree86 3.3.3 source code.

=head1 REQUESTS

This extension adds several requests, called as shown below:

  $x->XF86MiscQueryVersion => ($major, $minor)

  $x->XF86MiscGetSaver($screen) => ($suspendtime, $offtime)

  $x->XF86MiscSetSaver($screen, $suspendtime, $offtime)

  $x->XF86MiscGetMouseSettings => (%settings)

  $x->XF86MiscSetMouseSettings(%settings)

  $x->XF86MiscGetKbdSettings => ($type, $rate, $delay, $servnumlock)

  $x->XF86MiscSetKbdSettings($type, $rate, $delay, $servnumlock)

=head1 AUTHOR

Jay Kominek <jay.kominek@colorado.edu>

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>
