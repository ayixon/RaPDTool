# -*- perl -*-
#
# Copyright (C) 2004-2011 Daniel P. Berrange
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

Net::DBus::Binding::Message - Base class for messages

=head1 SYNOPSIS

Sending a message

  my $msg = new Net::DBus::Binding::Message::Signal;
  my $iterator = $msg->iterator;

  $iterator->append_byte(132);
  $iterator->append_int32(14241);

  $connection->send($msg);

=head1 DESCRIPTION

Provides a base class for the different kinds of
message that can be sent/received. Instances of
this class are never instantiated directly, rather
one of the four sub-types L<Net::DBus::Binding::Message::Signal>,
L<Net::DBus::Binding::Message::MethodCall>, L<Net::DBus::Binding::Message::MethodReturn>,
L<Net::DBus::Binding::Message::Error> should be used.

=head1 CONSTANTS

The following constants are defined in this module. They are
not exported into the caller's namespace & thus must be referenced
with their fully qualified package names

=over 4

=item TYPE_ARRAY

Constant representing the signature value associated with the
array data type.

=item TYPE_BOOLEAN

Constant representing the signature value associated with the
boolean data type.

=item TYPE_BYTE

Constant representing the signature value associated with the
byte data type.

=item TYPE_DICT_ENTRY

Constant representing the signature value associated with the
dictionary entry data type.

=item TYPE_DOUBLE

Constant representing the signature value associated with the
IEEE double precision floating point data type.

=item TYPE_INT16

Constant representing the signature value associated with the
signed 16 bit integer data type.

=item TYPE_INT32

Constant representing the signature value associated with the
signed 32 bit integer data type.

=item TYPE_INT64

Constant representing the signature value associated with the
signed 64 bit integer data type.

=item TYPE_OBJECT_PATH

Constant representing the signature value associated with the
object path data type.

=item TYPE_STRING

Constant representing the signature value associated with the
UTF-8 string data type.

=item TYPE_SIGNATURE

Constant representing the signature value associated with the
signature data type.

=item TYPE_STRUCT

Constant representing the signature value associated with the
struct data type.

=item TYPE_UINT16

Constant representing the signature value associated with the
unsigned 16 bit integer data type.

=item TYPE_UINT32

Constant representing the signature value associated with the
unsigned 32 bit integer data type.

=item TYPE_UINT64

Constant representing the signature value associated with the
unsigned 64 bit integer data type.

=item TYPE_VARIANT

Constant representing the signature value associated with the
variant data type.

=item TYPE_UNIX_FD

Constant representing the signature value associated with the
unix file descriptor data type.

=back

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Message;

use 5.006;
use strict;
use warnings;

use Net::DBus::Binding::Iterator;
use Net::DBus::Binding::Message::Signal;
use Net::DBus::Binding::Message::MethodCall;
use Net::DBus::Binding::Message::MethodReturn;
use Net::DBus::Binding::Message::Error;

=item my $msg = Net::DBus::Binding::Message->new(message => $rawmessage);

Creates a new message object, initializing it with the underlying C
message object given by the C<message> object. This constructor is
intended for internal use only, instead refer to one of the four
sub-types for this class for specific message types

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    $self->{message} = exists $params{message} ? $params{message} :
	(Net::DBus::Binding::Message::_create(exists $params{type} ? $params{type} : die "type parameter is required"));

    bless $self, $class;

    if ($class eq "Net::DBus::Binding::Message") {
	$self->_specialize;
    }

    return $self;
}

sub _specialize {
    my $self = shift;

    my $type = $self->get_type;
    if ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_CALL) {
	bless $self, "Net::DBus::Binding::Message::MethodCall";
    } elsif ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_RETURN) {
	bless $self, "Net::DBus::Binding::Message::MethodReturn";
    } elsif ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_ERROR) {
	bless $self, "Net::DBus::Binding::Message::Error";
    } elsif ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_SIGNAL) {
	bless $self, "Net::DBus::Binding::Message::Signal";
    } else {
	warn "Unknown message type $type\n";
    }
}

=item my $type = $msg->get_type

Retrieves the type code for this message. The returned value corresponds
to one of the four C<Net::DBus::Binding::Message::MESSAGE_TYPE_*> constants.

=cut

sub get_type {
    my $self = shift;

    return $self->{message}->dbus_message_get_type;
}

=item my $interface = $msg->get_interface

Retrieves the name of the interface targeted by this message, possibly
an empty string if there is no applicable interface for this message.

=cut

sub get_interface {
    my $self = shift;

    return $self->{message}->dbus_message_get_interface;
}

=item my $path = $msg->get_path

Retrieves the object path associated with the message, possibly an
empty string if there is no applicable object for this message.

=cut

sub get_path {
    my $self = shift;

    return $self->{message}->dbus_message_get_path;
}

=item my $name = $msg->get_destination

Retrieves the unique or well-known bus name for client intended to be
the recipient of the message. Possibly returns an empty string if
the message is being broadcast to all clients.

=cut

sub get_destination {
    my $self = shift;

    return $self->{message}->dbus_message_get_destination;
}

=item my $name = $msg->get_sender

Retireves the unique name of the client sending the message

=cut

sub get_sender {
    my $self = shift;

    return $self->{message}->dbus_message_get_sender;
}

=item my $serial = $msg->get_serial

Retrieves the unique serial number of this message. The number
is guaranteed unique for as long as the connection over which
the message was sent remains open. May return zero, if the message
is yet to be sent.

=cut

sub get_serial {
    my $self = shift;

    return $self->{message}->dbus_message_get_serial;
}

=item my $name = $msg->get_member

For method calls, retrieves the name of the method to be invoked,
while for signals, retrieves the name of the signal.

=cut

sub get_member {
    my $self = shift;

    return $self->{message}->dbus_message_get_member;
}

=item my $sig = $msg->get_signature

Retrieves a string representing the type signature of the values
packed into the body of the message.

=cut

sub get_signature {
    my $self = shift;

    return $self->{message}->dbus_message_get_signature;
}

=item $msg->set_sender($name)

Set the name of the client sending the message. The name must
be the unique name of the client.

=cut

sub set_sender {
    my $self = shift;
    $self->{message}->dbus_message_set_sender(@_);
}

=item $msg->set_destination($name)

Set the name of the intended recipient of the message. This is
typically used for signals to switch them from broadcast to
unicast.

=cut

sub set_destination {
    my $self = shift;
    $self->{message}->dbus_message_set_destination(@_);
}

=item my $iterator = $msg->iterator;

Retrieves an iterator which can be used for reading or
writing fields of the message. The returned object is
an instance of the C<Net::DBus::Binding::Iterator> class.

=cut

sub iterator {
    my $self = shift;
    my $append = @_ ? shift : 0;

    if ($append) {
	return Net::DBus::Binding::Message::_iterator_append($self->{message});
    } else {
	return Net::DBus::Binding::Message::_iterator($self->{message});
    }
}

=item $boolean = $msg->get_no_reply()

Gets the flag indicating whether the message is expecting
a reply to be sent.

=cut

sub get_no_reply {
    my $self = shift;

    return $self->{message}->dbus_message_get_no_reply;
}

=item $msg->set_no_reply($boolean)

Toggles the flag indicating whether the message is expecting
a reply to be sent. All method call messages expect a reply
by default. By toggling this flag the communication latency
is reduced by removing the need for the client to wait

=cut


sub set_no_reply {
    my $self = shift;
    my $flag = shift;

    $self->{message}->dbus_message_set_no_reply($flag);
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

# To keep autoloader quiet
sub DESTROY {
}

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;

    die "&Net::DBus::Binding::Message::constant not defined" if $constname eq '_constant';

    if (!exists $Net::DBus::Binding::Message::_constants{$constname}) {
        die "no such constant \$Net::DBus::Binding::Message::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Net::DBus::Binding::Message::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}

1;

=pod

=back

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2004-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Binding::Server>, L<Net::DBus::Binding::Connection>, L<Net::DBus::Binding::Message::Signal>, L<Net::DBus::Binding::Message::MethodCall>, L<Net::DBus::Binding::Message::MethodReturn>, L<Net::DBus::Binding::Message::Error>

=cut
