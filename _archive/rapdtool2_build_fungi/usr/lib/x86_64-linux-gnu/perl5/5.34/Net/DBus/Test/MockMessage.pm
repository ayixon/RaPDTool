# -*- perl -*-
#
# Copyright (C) 2005-2011 Daniel P. Berrange
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

Net::DBus::Test::MockMessage - Fake a message object when unit testing

=head1 SYNOPSIS

Sending a message

  my $msg = new Net::DBus::Test::MockMessage;
  my $iterator = $msg->iterator;

  $iterator->append_byte(132);
  $iterator->append_int32(14241);

  $connection->send($msg);

=head1 DESCRIPTION

This module provides a "mock" counterpart to the L<Net::DBus::Binding::Message>
class. It is basically a pure Perl fake message object providing the same
contract as the real message object. It is intended for use internally by the
testing APIs.

=head1 METHODS

=over 4

=cut

package Net::DBus::Test::MockMessage;

use 5.006;
use strict;
use warnings;

use vars qw($SERIAL);

BEGIN {
    $SERIAL = 1;
}

use Net::DBus::Binding::Message;
use Net::DBus::Test::MockIterator;

=item my $call = Net::DBus::Test::MockMessage->new_method_call(
  service_name => $service, object_path => $object,
  interface => $interface, method_name => $name);

Create a message representing a call on the object located at
the path C<object_path> within the client owning the well-known
name given by C<service_name>. The method to be invoked has
the name C<method_name> within the interface specified by the
C<interface> parameter.

=cut

sub new_method_call {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->_new(type => &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_CALL, @_);

    bless $self, $class;

    return $self;
}

=item my $msg = Net::DBus::Test::MockMessage->new_method_return(
    replyto => $method_call);

Create a message representing a reply to the method call passed in
the C<replyto> parameter.

=cut

sub new_method_return {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->_new(type => &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_RETURN, @_);

    bless $self, $class;

    return $self;
}

=item my $signal = Net::DBus::Test::MockMessage->new_signal(
      object_path => $path, interface => $interface, signal_name => $name);

Creates a new message, representing a signal [to be] emitted by
the object located under the path given by the C<object_path>
parameter. The name of the signal is given by the C<signal_name>
parameter, and is scoped to the interface given by the
C<interface> parameter.

=cut

sub new_signal {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->_new(type => &Net::DBus::Binding::Message::MESSAGE_TYPE_SIGNAL, @_);

    bless $self, $class;

    return $self;
}

=item my $msg = Net::DBus::Test::MockMessage->new_error(
      replyto => $method_call, name => $name, description => $description);

Creates a new message, representing an error which occurred during
the handling of the method call object passed in as the C<replyto>
parameter. The C<name> parameter is the formal name of the error
condition, while the C<description> is a short piece of text giving
more specific information on the error.

=cut

sub new_error {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->_new(type => &Net::DBus::Binding::Message::MESSAGE_TYPE_ERROR, @_);

    bless $self, $class;

    return $self;
}

sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    $self->{type} = exists $params{type} ? $params{type} : die "type parameter is required";
    $self->{interface} = exists $params{interface} ? $params{interface} : undef;
    $self->{path} = exists $params{path} ? $params{path} : undef;
    $self->{destination} = exists $params{destination} ? $params{destination} : undef;
    $self->{sender} = exists $params{sender} ? $params{sender} : undef;
    $self->{member} = exists $params{member} ? $params{member} : undef;
    $self->{error_name} = exists $params{error_name} ? $params{error_name} : undef;
    $self->{data} = [];
    $self->{no_reply} = 0;
    $self->{serial} = $SERIAL++;
    $self->{replyserial} = exists $params{replyto} ? $params{replyto}->get_serial : 0;

    bless $self, $class;

    if ($self->{type} == &Net::DBus::Binding::Message::MESSAGE_TYPE_ERROR) {
	my $desc = exists $params{error_description} ? $params{error_description} : "";
	my $iter = $self->iterator(1);
	$iter->append_string($desc);
    }

    return $self;
}


=item my $type = $msg->get_type

Retrieves the type code for this message. The returned value corresponds
to one of the four C<Net::DBus::Test::MockMessage::MESSAGE_TYPE_*> constants.

=cut

sub get_type {
    my $self = shift;

    return $self->{type};
}

=item my $name = $msg->get_error_name

Returns the formal name of the error, as previously passed in via
the C<name> parameter in the constructor.

=cut

sub get_error_name {
    my $self = shift;
    return $self->{error_name};
}

=item my $interface = $msg->get_interface

Retrieves the name of the interface targeted by this message, possibly
an empty string if there is no applicable interface for this message.

=cut

sub get_interface {
    my $self = shift;

    return $self->{interface};
}

=item my $path = $msg->get_path

Retrieves the object path associated with the message, possibly an
empty string if there is no applicable object for this message.

=cut

sub get_path {
    my $self = shift;

    return $self->{path};
}

=item my $name = $msg->get_destination

Retrieves the unique or well-known bus name for client intended to be
the recipient of the message. Possibly returns an empty string if
the message is being broadcast to all clients.

=cut

sub get_destination {
    my $self = shift;

    return $self->{destination};
}

=item my $name = $msg->get_sender

Retireves the unique name of the client sending the message

=cut

sub get_sender {
    my $self = shift;

    return $self->{sender};
}

=item my $serial = $msg->get_serial

Retrieves the unique serial number of this message. The number
is guaranteed unique for as long as the connection over which
the message was sent remains open. May return zero, if the message
is yet to be sent.

=cut

sub get_serial {
    my $self = shift;

    return $self->{serial};
}

=item my $name = $msg->get_member

For method calls, retrieves the name of the method to be invoked,
while for signals, retrieves the name of the signal.

=cut

sub get_member {
    my $self = shift;

    return $self->{member};
}


=item $msg->set_sender($name)

Set the name of the client sending the message. The name must
be the unique name of the client.

=cut

sub set_sender {
    my $self = shift;

    $self->{sender} = shift;
}

=item $msg->set_destination($name)

Set the name of the intended recipient of the message. This is
typically used for signals to switch them from broadcast to
unicast.

=cut

sub set_destination {
    my $self = shift;
    $self->{destination} = shift;
}

=item my $iterator = $msg->iterator;

Retrieves an iterator which can be used for reading or
writing fields of the message. The returned object is
an instance of the C<Net::DBus::Binding::Iterator> class.

=cut

sub iterator {
    my $self = shift;
    my $append = @_ ? shift : 0;

    return Net::DBus::Test::MockIterator->_new(data => $self->{data},
					       append => $append);
}

=item $boolean = $msg->get_no_reply()

Gets the flag indicating whether the message is expecting
a reply to be sent.

=cut

sub get_no_reply {
    my $self = shift;

    return $self->{no_reply};
}

=item $msg->set_no_reply($boolean)

Toggles the flag indicating whether the message is expecting
a reply to be sent. All method call messages expect a reply
by default. By toggling this flag the communication latency
is reduced by removing the need for the client to wait

=cut


sub set_no_reply {
    my $self = shift;

    $self->{no_reply} = shift;
}

=item my @values = $msg->get_args_list

De-marshall all the values in the body of the message, using the
message signature to identify data types. The values are returned
as a list.

=cut

sub get_args_list {
    my $self = shift;

    my @ret;
    my $iter = $self->iterator;
    if ($iter->get_arg_type() != &Net::DBus::Binding::Message::TYPE_INVALID) {
	do {
	    push @ret, $iter->get();
	} while ($iter->next);
    }

    return @ret;
}

=item $msg->append_args_list(@values)

Append a set of values to the body of the message. Values will
be encoded as either a string, list or dictionary as appropriate
to their Perl data type. For more specific data typing needs,
the L<Net::DBus::Binding::Iterator> object should be used instead.

=cut

sub append_args_list {
    my $self = shift;
    my @args = @_;

    my $iter = $self->iterator(1);
    foreach my $arg (@args) {
	$iter->append($arg);
    }
}

=item my $sig = $msg->get_signature

Retrieves a string representing the type signature of the values
packed into the body of the message.

=cut


sub get_signature {
    my $self = shift;

    my @bits = map { $self->_do_get_signature($_) } @{$self->{data}};
    return join ("", @bits);
}

sub _do_get_signature {
    my $self = shift;
    my $element = shift;

    if ($element->[0] == &Net::DBus::Binding::Message::TYPE_ARRAY) {
	return chr(&Net::DBus::Binding::Message::TYPE_ARRAY) . $element->[2];
    } elsif ($element->[0] == &Net::DBus::Binding::Message::TYPE_STRUCT) {
	my @bits = map { $self->_do_get_signature($_) } @{$element->[1]};
	return "{" . join("", @bits) . "}";
    } elsif ($element->[0] == &Net::DBus::Binding::Message::TYPE_VARIANT) {
	return chr(&Net::DBus::Binding::Message::TYPE_VARIANT);
    } else {
	return chr($element->[0]);
    }
}

1;

=pod

=back


=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2005-2009 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Binding::Message>, L<Net::DBus::Test::MockConnection>, L<Net::DBus::Test::MockIterator>

=cut
