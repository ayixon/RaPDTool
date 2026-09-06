# -*- perl -*-
#
# Copyright (C) 2006-2011 Daniel P. Berrange
#
# This program is free software; You can redistribute it and/or modify
# it under the same terms as Perl itself. Either:
#
# a) the GNU General Public License as published by the Free
#   Software Foundation; either version 2, or (at your option) any
#   later version,
#
# or
#
# b) the "Artistic License"
#
# The file "COPYING" distributed along with this file provides full
# details of the terms and conditions of the two licenses.

=pod

=head1 NAME

Net::DBus::Annotation - annotations for changing behaviour of APIs

=head1 SYNOPSIS

  use Net::DBus::Annotation qw(:call);

  my $object = $service->get_object("/org/example/systemMonitor");

  # Block until processes are listed
  my $processes = $object->list_processes("someuser");

  # Just throw away list of processes, pretty pointless
  # in this example, but useful if the method doesn't have
  # a return value
  $object->list_processes(dbus_call_noreply, "someuser");

  # List processes & get on with other work until
  # the list is returned.
  my $asyncreply = $object->list_processes(dbus_call_async, "someuser");

  ... some time later...
  my $processes = $asyncreply->get_data;


  # List processes, with a shorter 10 second timeout, instead of
  # the default 60 seconds
  my $object->list_processes(dbus_call_timeout, 10 * 1000, "someuser");

=head1 DESCRIPTION

This module provides a number of annotations which will be useful
when dealing with the DBus APIs. There are annotations for switching
remote calls between sync, async and no-reply mode. More annotations
may be added over time.

=head1 METHODS

=over 4

=cut

package Net::DBus::Annotation;

use strict;
use warnings;

our $CALL_SYNC = "sync";
our $CALL_ASYNC = "async";
our $CALL_NOREPLY = "noreply";
our $CALL_TIMEOUT = "timeout";

bless \$CALL_SYNC, __PACKAGE__;
bless \$CALL_ASYNC, __PACKAGE__;
bless \$CALL_NOREPLY, __PACKAGE__;
bless \$CALL_TIMEOUT, __PACKAGE__;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dbus_call_sync dbus_call_async dbus_call_noreply dbus_call_timeout);
our %EXPORT_TAGS = (call => [qw(dbus_call_sync dbus_call_async dbus_call_noreply dbus_call_timeout)]);

=item dbus_call_sync

Requests that a method call be performed synchronously, waiting
for the reply or error return to be received before continuing.

=cut

sub dbus_call_sync() {
    return \$CALL_SYNC;
}


=item dbus_call_async

Requests that a method call be performed a-synchronously, returning
a pending call object, which will collect the reply when it eventually
arrives.

=cut

sub dbus_call_async() {
    return \$CALL_ASYNC;
}

=item dbus_call_noreply

Requests that a method call be performed a-synchronously, discarding
any possible reply or error message.

=cut

sub dbus_call_noreply() {
    return \$CALL_NOREPLY;
}


=item dbus_call_timeout

Indicates that the next parameter for the method call will specify
the time to wait for a reply in milliseconds. If omitted, then the
default timeout for the object will be used

=cut

sub dbus_call_timeout() {
    return \$CALL_TIMEOUT;
}

1;

=pod

=back

=head1 AUTHOR

Daniel Berrange <dan@berrange.com>

=head1 COPYRIGHT

Copright (C) 2006-2011, Daniel Berrange.

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::RemoteObject>

=cut
