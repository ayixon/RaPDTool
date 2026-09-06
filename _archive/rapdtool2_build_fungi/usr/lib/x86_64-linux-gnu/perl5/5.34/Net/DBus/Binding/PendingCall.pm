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

Net::DBus::Binding::PendingCall - A handler for pending method replies

=head1 SYNOPSIS

  my $call = Net::DBus::Binding::PendingCall->new(method_call => $call,
                                                  pending_call => $reply);

  # Wait for completion
  $call->block;

  # And get the reply message
  my $msg = $call->get_reply;

=head1 DESCRIPTION

This object is used when it is necessary to make asynchronous method
calls. It provides the means to be notified when the reply is finally
received.

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::PendingCall;

use 5.006;
use strict;
use warnings;

use Net::DBus;
use Net::DBus::Binding::Message::MethodReturn;
use Net::DBus::Binding::Message::Error;

=item my $call = Net::DBus::Binding::PendingCall->new(method_call => $method_call,
                                                      pending_call => $pending_call);

Creates a new pending call object, with the C<method_call> parameter
being a reference to the C<Net::DBus::Binding::Message::MethodCall>
object whose reply is being waiting for. The C<pending_call> parameter
is a reference to the raw C pending call object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    $self->{connection} = exists $params{connection} ? $params{connection} : die "connection parameter is required";
    $self->{method_call} = exists $params{method_call} ? $params{method_call} : die "method_call parameter is required";
    $self->{pending_call} = exists $params{pending_call} ? $params{pending_call} : die "pending_call parameter is required";

    bless $self, $class;

    return $self;
}

=item $call->cancel

Cancel the pending call, causing any reply that is later received
to be discarded.

=cut

sub cancel {
    my $self = shift;

    $self->{pending_call}->dbus_pending_call_cancel();
}


=item my $boolean = $call->get_completed

Returns a true value if the pending call has received its reply,
or a timeout has occurred.

=cut

sub get_completed {
    my $self = shift;

    $self->{pending_call}->dbus_pending_call_get_completed();
}

=item $call->block

Block the caller until the reply is received or a timeout
occurrs.

=cut

sub block {
    my $self = shift;

    $self->{pending_call}->dbus_pending_call_block();
}

=item my $msg = $call->get_reply;

Retrieves the C<Net::DBus::Binding::Message> object associated
with the complete call.

=cut

sub get_reply {
    my $self = shift;

    my $reply = $self->{pending_call}->_steal_reply();
    my $type = $reply->dbus_message_get_type;
    if ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_ERROR) {
	return $self->{connection}->make_raw_message($reply);
    } elsif ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_RETURN) {
	return $self->{connection}->make_raw_message($reply);
    } else {
	die "unknown method reply type $type";
    }
}

=item $call->set_notify($coderef);

Sets a notification function to be invoked when the pending
call completes. The callback will be passed a single argument
which is this pending call object.

=cut

sub set_notify {
    my $self = shift;
    my $cb = shift;

    $self->{pending_call}->_set_notify($cb);
}

1;

=pod

=back

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2006-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Binding::Connection>, L<Net::DBus::Binding::Message>, L<Net::DBus::ASyncReply>

=cut
