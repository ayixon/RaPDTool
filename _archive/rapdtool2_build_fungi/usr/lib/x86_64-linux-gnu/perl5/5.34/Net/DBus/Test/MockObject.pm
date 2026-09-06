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

Net::DBus::Test::MockObject - Fake an object from the bus for unit testing

=head1 SYNOPSIS

  use Net::DBus;
  use Net::DBus::Test::MockObject;

  my $bus = Net::DBus->test

  # Lets fake presence of HAL...

  # First we need to define the service
  my $service = $bus->export_service("org.freedesktop.Hal");

  # Then create a mock object
  my $object = Net::DBus::Test::MockObject->new($service,
                                                "/org/freedesktop/Hal/Manager");

  # Fake the 'GetAllDevices' method
  $object->seed_action("org.freedesktop.Hal.Manager",
                       "GetAllDevices",
                       reply => {
                         return => [ "/org/freedesktop/Hal/devices/computer_i8042_Aux_Port",
                                     "/org/freedesktop/Hal/devices/computer_i8042_Aux_Port_logicaldev_input",
                                     "/org/freedesktop/Hal/devices/computer_i8042_Kbd_Port",
                                     "/org/freedesktop/Hal/devices/computer_i8042_Kbd_Port_logicaldev_input"
                         ],
                       });


  # Now can test any class which calls out to 'GetAllDevices' in HAL
  ....test stuff....

=head1 DESCRIPTION

This provides an alternate for L<Net::DBus::Object> to enable bus
objects to be quickly mocked up, thus facilitating creation of unit
tests for services which may need to call out to objects provided
by 3rd party services on the bus. It is typically used as a companion
to the L<Net::DBus::MockBus> object, to enable complex services to
be tested without actually starting a real bus.

!!!!! WARNING !!!

This object & its APIs should be considered very experimental at
this point in time, and no guarantees about future API compatibility
are provided what-so-ever. Comments & suggestions on how to evolve
this framework are, however, welcome & encouraged.

=head1 METHODS

=over 4

=cut

package Net::DBus::Test::MockObject;

use strict;
use warnings;

=item my $object = Net::DBus::Test::MockObject->new($service, $path, $interface);

Create a new mock object, attaching to the service defined by the C<$service>
parameter. This would be an instance of the L<Net::DBus::Service> object. The
C<$path> parameter defines the object path at which to attach this mock object,
and C<$interface> defines the interface it will support.

=cut

sub new {
    my $class = shift;
    my $self = {};

    $self->{service} = shift;
    $self->{object_path} = shift;
    $self->{interface} = shift;
    $self->{actions} = {};
    $self->{message} = shift;

    bless $self, $class;

    $self->get_service->_register_object($self);

    return $self;
}


sub _get_sub_nodes {
    my $self = shift;
    return [];
}

=item my $service = $object->get_service

Retrieves the L<Net::DBus::Service> object within which this
object is exported.

=cut

sub get_service {
    my $self = shift;
    return $self->{service};
}

=item my $path = $object->get_object_path

Retrieves the path under which this object is exported

=cut

sub get_object_path {
    my $self = shift;
    return $self->{object_path};
}


=item my $msg = $object->get_last_message

Retrieves the last message processed by this object. The returned
object is an instance of L<Net::DBus::Binding::Message>

=cut

sub get_last_message {
    my $self = shift;
    return $self->{message};
}

=item my $sig = $object->get_last_message_signature

Retrieves the type signature of the last processed message.

=cut

sub get_last_message_signature {
    my $self = shift;
    return $self->{message}->get_signature;
}

=item my $value = $object->get_last_message_param

Returns the first value supplied as an argument to the last
processed message.

=cut

sub get_last_message_param {
    my $self = shift;
    my @args = $self->{message}->get_args_list;
    return $args[0];
}

=item my @values = $object->get_last_message_param_list

Returns a list of all the values supplied as arguments to
the last processed message.

=cut

sub get_last_message_param_list {
    my $self = shift;
    my @args = $self->{message}->get_args_list;
    return \@args;
}

=item $object->seed_action($interface, $method, %action);

Registers an action to be performed when a message corresponding
to the method C<$method> within the interface C<$interface> is
received. The C<%action> parameter can have a number of possible
keys set:

=over 4

=item signals

Causes a signal to be emitted when the method is invoked. The
value associated with this key should be an instance of the
L<Net::DBus::Binding::Message::Signal> class.

=item error

Causes an error to be generated when the method is invoked. The
value associated with this key should be a hash reference, with
two elements. The first, C<name>, giving the error name, and the
second, C<description>, providing the descriptive text.

=item reply

Causes a normal method return to be generated. The value associated
with this key should be an array reference, whose elements are the
values to be returned by the method.

=back

=cut

sub seed_action {
    my $self = shift;
    my $interface = shift;
    my $method = shift;
    my %action = @_;

    $self->{actions}->{$method} = {} unless exists $self->{actions}->{$method};
    $self->{actions}->{$method}->{$interface} = \%action;
}

sub _dispatch {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    my $interface = $message->get_interface;
    my $method = $message->get_member;

    my $con = $self->get_service->get_bus->get_connection;

    if (!exists $self->{actions}->{$method}) {
	my $error = $con->make_error_message($message,
					     "org.freedesktop.DBus.Failed",
					     "no action seeded for method " . $message->get_member);
	$con->send($error);
	return;
    }

    my $action;
    if ($interface) {
	if (!exists $self->{actions}->{$method}->{$interface}) {
	    my $error = $con->make_error_message($message,
						 "org.freedesktop.DBus.Failed",
						 "no action with correct interface seeded for method " . $message->get_member);
	    $con->send($error);
	    return;
	}
	$action = $self->{actions}->{$method}->{$interface};
    } else {
	my @interfaces = keys %{$self->{actions}->{$method}};
	if ($#interfaces > 0) {
	    my $error = $con->make_error_message($message,
						 "org.freedesktop.DBus.Failed",
						 "too many actions seeded for method " . $message->get_member);
	    $con->send($error);
	    return;
	}
	$action = $self->{actions}->{$method}->{$interfaces[0]};
    }

    if (exists $action->{signals}) {
	my $sigs = $action->{signals};
	if (ref($sigs) ne "ARRAY") {
	    $sigs = [ $sigs ];
	}
	foreach my $sig (@{$sigs}) {
	    $self->get_service->get_bus->get_connection->send($sig);
	}
    }

    $self->{message} = $message;

    if (exists $action->{error}) {
	my $error = $con->make_error_message($message,
					     $action->{error}->{name},
					     $action->{error}->{description});
	$con->send($error);
    } elsif (exists $action->{reply}) {
	my $reply = $con->make_method_return_message($message);
	my $iter = $reply->iterator(1);
	foreach my $value (@{$action->{reply}->{return}}) {
	    $iter->append($value);
	}
	$con->send($reply);
    }
}


1;

=pod

=back

=head1 BUGS

It doesn't completely replicate the API of L<Net::DBus::Binding::Object>,
merely enough to make the high level bindings work in a test scenario.

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2004-2009 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Object>, L<Net::DBus::Test::MockConnection>,
L<http://www.mockobjects.com/Faq.html>

=cut
