#!/usr/bin/perl

package X11::Protocol::Ext::DPMS; # The Display Power Management Signaling
                                  # Extension

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
  $x->{'ext_const'}{'DPMSPowerLevels'} = ['DPMSModeOn','DPMSModeStandby',
					  'DPMSModeSuspend','DPMSModeOff'];
  $x->{'ext_const_num'}{'DPMSPowerLevels'} =
    {make_num_hash($x->{'ext_const'}{'DPMSPowerLevels'})};
  
  # Events
  
  # Requests
  $x->{'ext_request'}{$request_num} =
    [
     ["DPMSGetVersion", sub {
	my($self) = shift;
	return pack("SS",1,1);
      }, sub {
	my($self) = shift;
	my($data) = @_;
	my($major,$minor) = unpack("xxxxxxxxSSxxxxxxxxxxxxxxxxxxxx",$data);
	return($major,$minor);
      }],
     ["DPMSCapable", sub {
	my($self) = shift;
	return "";
      }, sub {
	my($self) = shift;
	my($data) = @_;
	my($capable) = unpack("xxxxxxxxCxxxxxxxxxxxxxxxxxxxxxxx",$data);
	return($capable);
      }],
     ["DPMSGetTimeouts", sub {
	my($self) = shift;
	return "";
      }, sub {
	my($self) = shift;
	my($data) = @_;
	my($standby,$suspend,$off) =
	  unpack("xxxxxxxxSSSxxxxxxxxxxxxxxxxxx",$data);
	return($standby,$suspend,$off);
      }],
     ["DPMSSetTimeouts", sub {
	my($self) = shift;
	my($standby,$suspend,$off) = @_;
	return pack("SSSxx",$standby,$suspend,$off);
      }],
     ["DPMSEnable", sub {
	my($self) = shift;
	return "";
      }],
     ["DPMSDisable", sub {
	my($self) = shift;
	return "";
      }],
     ["DPMSForceLevel", sub {
	my($self) = shift;
	return(pack("Sxx",$self->num('DPMSPowerLevels',@_[0])));
      }],
     ["DPMSInfo", sub {
	my($self) = shift;
	return "";
      }, sub {
	my($self) = shift;
	my($data) = @_;
	my($power_level,$state) =
	  unpack("xxxxxxxxSCxxxxxxxxxxxxxxxxxxxxx",$data);
	return($self->interp('DPMSPowerLevels',$power_level),$state);
      }]
    ];
  my($i);
  for $i (0 .. $#{$x->{'ext_request'}{$request_num}})
    {
      $x->{'ext_request_num'}{$x->{'ext_request'}{$request_num}[$i][0]}
	= [$request_num, $i];
    }
  ($self->{'major'}, $self->{'minor'}) = $x->req('DPMSGetVersion');
  return bless $self, $pkg;
}

1;
__END__

=head1 NAME

X11::Protocol::Ext::DPMS - Perl module for the X11 Protocol DPMS Extension

=head1 SYNOPSIS

  use X11::Protocol;
  $x = X11::Protocol->new();
  $x->init_extension('DPMS');

=head1 DESCRIPTION

This module is used to control the DPMS features of compliant monitors.

=head1 SYMBOLIC CONSTANTS

This extension adds the constant type DPMSPowerLevels, with values as
defined in the standard.

=head1 REQUESTS

This extension adds several requests, called as shown below:

  $x->DPMSGetVersion => ($major, $minor)

  $x->DPMSCapable => ($capable)

  $x->DPMSGetTimeouts => ($standby_timeout, $suspend_timeout, $off_timeout)

  $x->DPMSSetTimeouts($standby_timeout, $suspend_timeout, $off_timeout) => ()

  $x->DPMSEnable => ()

  $x->DPMSDisable => ()

  $x->DPMSForceLevel($power_level) => ()

  $x->DPMSInfo => ($power_level,$state)

=head1 AUTHOR

Jay Kominek <jay.kominek@colorado.edu>

=head1 SEE ALSO

L<perl(1)>,
L<X11::Protocol>,
I<X Display Power Management Signaling (DPMS) Extension (X Consortium Standard)>
