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

Net::DBus - Perl extension for the DBus message system

=head1 SYNOPSIS


  ####### Attaching to the bus ###########

  use Net::DBus;

  # Find the most appropriate bus
  my $bus = Net::DBus->find;

  # ... or explicitly go for the session bus
  my $bus = Net::DBus->session;

  # .... or explicitly go for the system bus
  my $bus = Net::DBus->system


  ######## Accessing remote services #########

  # Get a handle to the HAL service
  my $hal = $bus->get_service("org.freedesktop.Hal");

  # Get the device manager
  my $manager = $hal->get_object("/org/freedesktop/Hal/Manager",
				 "org.freedesktop.Hal.Manager");

  # List devices
  foreach my $dev (@{$manager->GetAllDevices}) {
      print $dev, "\n";
  }


  ######### Providing services ##############

  # Register a service known as 'org.example.Jukebox'
  my $service = $bus->export_service("org.example.Jukebox");


=head1 DESCRIPTION

Net::DBus provides a Perl API for the DBus message system.
The DBus Perl interface is currently operating against
the 0.32 development version of DBus, but should work with
later versions too, providing the API changes have not been
too drastic.

Users of this package are either typically, service providers
in which case the L<Net::DBus::Service> and L<Net::DBus::Object>
modules are of most relevance, or are client consumers, in which
case L<Net::DBus::RemoteService> and L<Net::DBus::RemoteObject>
are of most relevance.

=head1 METHODS

=over 4

=cut

package Net::DBus;

use 5.006;
use strict;
use warnings;

BEGIN {
    our $VERSION = '1.2.0';
    require XSLoader;
    XSLoader::load('Net::DBus', $VERSION);
}

use Net::DBus::Binding::Bus;
use Net::DBus::Service;
use Net::DBus::RemoteService;
use Net::DBus::Test::MockConnection;
use Net::DBus::Binding::Value;

use vars qw($bus_system $bus_session);

use Exporter qw(import);

use vars qw(@EXPORT_OK %EXPORT_TAGS);

@EXPORT_OK = qw(dbus_int16 dbus_uint16 dbus_int32 dbus_uint32 dbus_int64 dbus_uint64
		dbus_byte dbus_boolean dbus_string dbus_double
		dbus_object_path dbus_signature dbus_unix_fd
		dbus_struct dbus_array dbus_dict dbus_variant);

%EXPORT_TAGS = (typing => [qw(dbus_int16 dbus_uint16 dbus_int32 dbus_uint32 dbus_int64 dbus_uint64
			      dbus_byte dbus_boolean dbus_string dbus_double
			      dbus_object_path dbus_signature dbus_unix_fd
			      dbus_struct dbus_array dbus_dict dbus_variant)]);

=item my $bus = Net::DBus->find(%params);

Search for the most appropriate bus to connect to and
return a connection to it. The heuristic used for the
search is

  - If DBUS_STARTER_BUS_TYPE is set to 'session' attach
    to the session bus

  - Else If DBUS_STARTER_BUS_TYPE is set to 'system' attach
    to the system bus

  - Else If DBUS_SESSION_BUS_ADDRESS is set attach to the
    session bus

  - Else attach to the system bus

The optional C<params> hash can contain be used to specify
connection options. The only support option at this time
is C<nomainloop> which prevents the bus from being automatically
attached to the main L<Net::DBus::Reactor> event loop.

=cut

sub find {
    my $class = shift;

    if ($ENV{DBUS_STARTER_BUS_TYPE} &&
	$ENV{DBUS_STARTER_BUS_TYPE} eq "session") {
	return $class->session(@_);
    } elsif ($ENV{DBUS_STARTER_BUS_TYPE} &&
	     $ENV{DBUS_STARTER_BUS_TYPE} eq "system") {
	return $class->system(@_);
    } elsif (exists $ENV{DBUS_SESSION_BUS_ADDRESS}) {
	return $class->session(@_);
    } else {
	return $class->system(@_);
    }
}

=item my $bus = Net::DBus->system(%params);

Return a handle for the system message bus. Note that the
system message bus is locked down by default, so unless appropriate
access control rules are added in /etc/dbus/system.d/, an application
may access services, but won't be able to export services.

The optional C<params> hash can be used to specify the following options:

=over

=item nomainloop

If true, prevents the bus from being automatically attached to the main
L<Net::DBus::Reactor> event loop.

=item private

If true, the socket opened is private; any existing socket will be ignored and
any future attempts to open the same bus will return a different existing socket
or open a fresh one.

=back

=cut

sub system {
    my $class = shift;
    my %params = @_;
    if ($params{private}) {
	return $class->_new(Net::DBus::Binding::Bus->new(type => &Net::DBus::Binding::Bus::SYSTEM, private => 1), @_);
    }

    unless ($bus_system) {
	$bus_system = $class->_new(Net::DBus::Binding::Bus->new(type => &Net::DBus::Binding::Bus::SYSTEM), @_);
    }
    return $bus_system
}

=item my $bus = Net::DBus->session(%params);

Return a handle for the session message bus.

The optional C<params> hash can be used to specify the following options:

=over

=item nomainloop

If true, prevents the bus from being automatically attached to the main
L<Net::DBus::Reactor> event loop.

=item private

If true, the socket opened is private; any existing socket will be ignored and
any future attempts to open the same bus will return a different existing socket
or open a fresh one.

=back

=cut

sub session {
    my $class = shift;
    my %params = @_;
    if ($params{private}) {
	return $class->_new(Net::DBus::Binding::Bus->new(type => &Net::DBus::Binding::Bus::SESSION, private => 1), @_);
    }

    unless ($bus_session) {
	$bus_session = $class->_new(Net::DBus::Binding::Bus->new(type => &Net::DBus::Binding::Bus::SESSION), @_);
    }
    return $bus_session;
}


=item my $bus = Net::DBus->test(%params);

Returns a handle for a virtual bus for use in unit tests. This bus does
not make any network connections, but rather has an in-memory message
pipeline. Consult L<Net::DBus::Test::MockConnection> for further details
of how to use this special bus.

=cut

# NB. explicitly do *NOT* cache, since unit tests
# should always have pristine state
sub test {
    my $class = shift;
    return $class->_new(Net::DBus::Test::MockConnection->new());
}

=item my $bus = Net::DBus->new($address, %params);

Return a connection to a specific message bus.  The C<$address>
parameter must contain the address of the message bus to connect
to. An example address for a session bus might look like
C<unix:abstract=/tmp/dbus-PBFyyuUiVb,guid=191e0a43c3efc222e0818be556d67500>,
while one for a system bus would look like C<unix:/var/run/dbus/system_bus_socket>.
The optional C<params> hash can contain be used to specify
connection options. The only support option at this time
is C<nomainloop> which prevents the bus from being automatically
attached to the main L<Net::DBus::Reactor> event loop.

=cut

sub new {
    my $class = shift;
    return $class->_new(Net::DBus::Binding::Bus->new(address => shift), @_);
}

sub _new {
    my $class = shift;
    my $self = {};

    $self->{connection} = shift;
    $self->{signals} = [];
    # Map well known names to RemoteService objects
    $self->{services} = {};
    $self->{timeout} = 60 * 1000;

    my %params = @_;

    bless $self, $class;

    unless ($params{nomainloop}) {
	if (exists $INC{'Net/DBus/Reactor.pm'}) {
	    my $reactor = $params{reactor} ? $params{reactor} : Net::DBus::Reactor->main;
	    $reactor->manage($self->get_connection);
	}
	# ... Add support for GLib and POE
    }

    $self->get_connection->add_filter(sub { return $self->_signal_func(@_); });

    $self->{bus} = $self->{services}->{"org.freedesktop.DBus"} =
	Net::DBus::RemoteService->new($self, "org.freedesktop.DBus", "org.freedesktop.DBus");
    $self->get_bus_object()->connect_to_signal('NameOwnerChanged', sub {
	my ($svc, $old, $new) = @_;
	# Slightly evil poking into the private 'owner_name' field here
	if (exists $self->{services}->{$svc}) {
	    $self->{services}->{$svc}->{owner_name} = $new;
	}
    });

    return $self;
}

=item my $connection = $bus->get_connection;

Return a handle to the underlying, low level connection object
associated with this bus. The returned object will be an instance
of the L<Net::DBus::Binding::Bus> class. This method is not intended
for use by (most!) application developers, so if you don't understand
what this is for, then you don't need to be calling it!

=cut

sub get_connection {
    my $self = shift;
    return $self->{connection};
}

=item my $service = $bus->get_service($name);

Retrieves a handle for the remote service identified by the
service name C<$name>. The returned object will be an instance
of the L<Net::DBus::RemoteService> class.

=cut

sub get_service {
    my $self = shift;
    my $name = shift;

    if ($name eq "org.freedesktop.DBus") {
	return $self->{bus};
    }

    if (!exists $self->{services}->{$name}) {
	my $owner = $name;
	if ($owner !~ /^:/) {
	    $owner = $self->get_service_owner($name);
	    if (!defined $owner) {
		$self->get_bus_object->StartServiceByName($name, 0);
		$owner = $self->get_service_owner($name);
	    }
	}
	$self->{services}->{$name} = Net::DBus::RemoteService->new($self, $owner, $name);
    }
    return $self->{services}->{$name};
}

=item my $service = $bus->export_service($name);

Registers a service with the bus, returning a handle to
the service. The returned object is an instance of the
L<Net::DBus::Service> class.

When C<$name> is not specified or is C<undef> then returned
handle to the service is identified only by the unique name
of client's connection to the bus.

=cut

sub export_service {
    my $self = shift;
    my $name = shift;
    return Net::DBus::Service->new($self, $name);
}

=item my $object = $bus->get_bus_object;

Retrieves a handle to the bus object, C</org/freedesktop/DBus>,
provided by the service C<org.freedesktop.DBus>. The returned
object is an instance of L<Net::DBus::RemoteObject>

=cut

sub get_bus_object {
    my $self = shift;

    my $service = $self->get_service("org.freedesktop.DBus");
    return $service->get_object('/org/freedesktop/DBus',
				'org.freedesktop.DBus');
}


=item my $name = $bus->get_unique_name;

Retrieves the unique name of this client's connection to
the bus.

=cut

sub get_unique_name {
    my $self = shift;

    return $self->get_connection->get_unique_name
}

=item my $name = $bus->get_service_owner($service);

Retrieves the unique name of the client on the bus owning
the service named by the C<$service> parameter.

=cut

sub get_service_owner {
    my $self = shift;
    my $service = shift;

    my $bus = $self->get_bus_object;
    my $owner = eval {
	$bus->GetNameOwner($service);
    };
    if ($@) {
	if (UNIVERSAL::isa($@, "Net::DBus::Error") &&
	    $@->{name} eq "org.freedesktop.DBus.Error.NameHasNoOwner") {
	    $owner = undef;
	} else {
	    die $@;
	}
    }
    return $owner;
}

=item my $timeout = $bus->timeout(60 * 1000);

Sets or retrieves the timeout value which will be used for DBus
requests belongs to this bus connection. The timeout should be
specified in milliseconds, with the default value being 60 seconds.

=cut

sub timeout {
    my $self = shift;
    if (@_) {
        $self->{timeout} = shift;
    }
    return $self->{timeout};
}

sub _add_signal_receiver {
    my $self = shift;
    my $receiver = shift;
    my $signal_name = shift;
    my $interface = shift;
    my $service = shift;
    my $path = shift;

    my $rule = $self->_match_rule($signal_name, $interface, $service, $path);
    push @{$self->{signals}}, { cb => $receiver,
				rule => $rule,
				signal_name => $signal_name,
				interface => $interface,
				service => $service,
				path => $path };
    $self->{connection}->add_match($rule);
}

sub _remove_signal_receiver {
    my $self = shift;
    my $receiver = shift;
    my $signal_name = shift;
    my $interface = shift;
    my $service = shift;
    my $path = shift;

    my $rule = $self->_match_rule($signal_name, $interface, $service, $path);
    my @signals;
    foreach (@{$self->{signals}}) {
	if ($_->{cb} eq $receiver &&
	    $_->{rule} eq $rule) {
	    $self->{connection}->remove_match($rule);
	} else {
	    push @signals, $_;
	}
    }
    $self->{signals} = \@signals;
}


sub _match_rule {
    my $self = shift;
    my $signal_name = shift;
    my $interface = shift;
    my $service = shift;
    my $path = shift;

    my $rule = "type='signal'";
    if (defined $interface) {
	$rule .= ",interface='$interface'";
    }
    if (defined $path) {
	$rule .= ",path='$path'";
    }
    if (defined $service) {
	$rule .= ",sender='$service'";
    }
    if (defined $signal_name) {
	$rule .= ",member='$signal_name'";
    }
    return $rule;
}


sub _handler_matches {
    my $self = shift;
    my $handler = shift;
    my $signal_name = shift;
    my $interface = shift;
    my $sender = shift;
    my $path = shift;

    if (defined $handler->{signal_name} &&
	$handler->{signal_name} ne $signal_name) {
	return 0;
    }
    if (defined $handler->{interface} &&
	$handler->{interface} ne $interface) {
	return 0;
    }
    if (defined $handler->{path} &&
	$handler->{path} ne $path) {
	return 0;
    }

    if (defined $handler->{service}) {
	my $owner = $self->{services}->{$handler->{service}};
	return 0 unless defined $owner;
	return 0 unless $owner->get_owner_name eq $sender;
    }

    return 1;
}

sub _signal_func {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    return 0 unless $message->get_type() == &Net::DBus::Binding::Message::MESSAGE_TYPE_SIGNAL;

    my $interface = $message->get_interface;
    my $sender = $message->get_sender;
    my $path = $message->get_path;
    my $signal_name = $message->get_member;

    my $handled = 0;
    foreach my $handler (@{$self->{signals}}) {
	next unless $self->_handler_matches($handler, $signal_name, $interface, $sender, $path);
	my $callback = $handler->{cb};
	&$callback($message);
	$handled = 1;
    }

    return $handled;
}

=back

=head1 DATA TYPING METHODS

These methods are not usually used, since most services provide introspection
data to inform clients of their data typing requirements. If introspection data
is incomplete, however, it may be necessary for a client to mark values with
specific data types. In such a case, the following methods can be used. They
are not, however, exported by default so must be requested at import time by
specifying 'use Net::DBus qw(:typing)'

=over 4

=item $typed_value = dbus_int16($value);

Mark a value as being a signed, 16-bit integer.

=cut

sub dbus_int16 {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_INT16,
					  $_[0]);

}

=item $typed_value = dbus_uint16($value);

Mark a value as being an unsigned, 16-bit integer.

=cut


sub dbus_uint16 {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_UINT16,
					  $_[0]);
}

=item $typed_value = dbus_int32($value);

Mark a value as being a signed, 32-bit integer.

=cut

sub dbus_int32 {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_INT32,
					  $_[0]);

}

=item $typed_value = dbus_uint32($value);

Mark a value as being an unsigned, 32-bit integer.

=cut


sub dbus_uint32 {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_UINT32,
					  $_[0]);
}

=item $typed_value = dbus_int64($value);

Mark a value as being an unsigned, 64-bit integer.

=cut



sub dbus_int64 {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_INT64,
					  $_[0]);

}

=item $typed_value = dbus_uint64($value);

Mark a value as being an unsigned, 64-bit integer.

=cut



sub dbus_uint64 {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_UINT64,
					  $_[0]);
}

=item $typed_value = dbus_double($value);

Mark a value as being a double precision IEEE floating point.

=cut



sub dbus_double {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_DOUBLE,
					  $_[0]);
}

=item $typed_value = dbus_byte($value);

Mark a value as being an unsigned, byte.

=cut



sub dbus_byte {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_BYTE,
					  $_[0]);
}

=item $typed_value = dbus_string($value);

Mark a value as being a UTF-8 string. This is not usually required
since 'string' is the default data type for any Perl scalar value.

=cut



sub dbus_string {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_STRING,
					  $_[0]);
}

=item $typed_value = dbus_signature($value);

Mark a value as being a UTF-8 string, whose contents is a valid
type signature

=cut



sub dbus_signature {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_SIGNATURE,
					  $_[0]);
}

=item $typed_value = dbus_object_path($value);

Mark a value as being a UTF-8 string, whose contents is a valid
object path.

=cut

sub dbus_object_path {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_OBJECT_PATH,
					  $_[0]);
}

=item $typed_value = dbus_boolean($value);

Mark a value as being an boolean

=cut



sub dbus_boolean {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_BOOLEAN,
					  $_[0]);
}

=item $typed_value = dbus_array($value);

Mark a value as being an array

=cut


sub dbus_array {
    return Net::DBus::Binding::Value->new([&Net::DBus::Binding::Message::TYPE_ARRAY],
					  $_[0]);
}

=item $typed_value = dbus_struct($value);

Mark a value as being a structure

=cut


sub dbus_struct {
    return Net::DBus::Binding::Value->new([&Net::DBus::Binding::Message::TYPE_STRUCT],
					  $_[0]);
}

=item $typed_value = dbus_dict($value);

Mark a value as being a dictionary

=cut

sub dbus_dict {
    return Net::DBus::Binding::Value->new([&Net::DBus::Binding::Message::TYPE_DICT_ENTRY],
					  $_[0]);
}

=item $typed_value = dbus_variant($value);

Mark a value as being a variant

=cut

sub dbus_variant {
    return Net::DBus::Binding::Value->new([&Net::DBus::Binding::Message::TYPE_VARIANT],
					  $_[0]);
}

=item $typed_value = dbus_unix_fd($value);

Mark a value as being a unix file descriptor

=cut

sub dbus_unix_fd {
    return Net::DBus::Binding::Value->new(&Net::DBus::Binding::Message::TYPE_UNIX_FD,
                                          $_[0]);
}

=pod

=back

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::RemoteService>, L<Net::DBus::Service>,
L<Net::DBus::RemoteObject>, L<Net::DBus::Object>,
L<Net::DBus::Exporter>, L<Net::DBus::Dumper>, L<Net::DBus::Reactor>,
C<dbus-monitor(1)>, C<dbus-daemon-1(1)>, C<dbus-send(1)>, L<http://dbus.freedesktop.org>,

=head1 AUTHOR

Daniel Berrange <dan@berrange.com>

=head1 COPYRIGHT

Copyright 2004-2011 by Daniel Berrange

=cut

1;
