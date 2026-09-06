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

Net::DBus::BaseObject - base class for exporting objects to the bus

=head1 SYNOPSIS

  # We're going to be a DBus object
  use base qw(Net::DBus::BaseObject);

  # Export a 'Greeting' signal taking a stringl string parameter
  dbus_signal("Greeting", ["string"]);

  # Export 'Hello' as a method accepting a single string
  # parameter, and returning a single string value
  dbus_method("Hello", ["string"], ["string"]);

  sub new {
      my $class = shift;
      my $service = shift;
      my $self = $class->SUPER::new($service, "/org/demo/HelloWorld");

      bless $self, $class;

      return $self;
  }

  sub _dispatch_object {
      my $self = shift;
      my $connection = shift;
      my $message = shift;

      if (....$message refers to a object's method ... ) {
         ...dispatch this object's interfaces/methods...
         return $reply;
      }
  }

=head1 DESCRIPTION

This the base of all objects which are exported to the
message bus. It provides the core support for type introspection
required for objects exported to the message. When sub-classing
this object, the C<_dispatch> object should be implemented to
handle processing of incoming messages. The L<Net::DBus::Exporter>
module is used to declare which methods (and signals) are being
exported to the message bus.

All packages inheriting from this, will automatically have the
interface C<org.freedesktop.DBus.Introspectable> registered
with L<Net::DBus::Exporter>, and the C<Introspect> method within
this exported.

Application developers will rarely want to use this class directly,
instead either L<Net::DBus::Object> or C<Net::DBus::ProxyObject>
are the common choices. This class will only be used if wanting to
write a new approach to dispatching incoming method calls.

=head1 METHODS

=over 4

=cut

package Net::DBus::BaseObject;

use 5.006;
use strict;
use warnings;

our $ENABLE_INTROSPECT;

BEGIN {
    if ($ENV{DBUS_DISABLE_INTROSPECT}) {
	$ENABLE_INTROSPECT = 0;
    } else {
	$ENABLE_INTROSPECT = 1;
    }
}

use Net::DBus::Exporter "org.freedesktop.DBus.Introspectable";

dbus_method("Introspect", [], ["string"], {return_names => ["xml_data"]});

dbus_method("Get", ["string", "string"], [["variant"]], "org.freedesktop.DBus.Properties", {return_names => ["value"], param_names => ["interface_name", "property_name"]});
dbus_method("GetAll", ["string"], [["dict", "string", ["variant"]]], "org.freedesktop.DBus.Properties", {return_names => ["properties"], param_names => ["interface_name"]});
dbus_method("Set", ["string", "string", ["variant"]], [], "org.freedesktop.DBus.Properties", {param_names => ["interface_name", "property_name", "value"]});

=item my $object = Net::DBus::BaseObject->new($service, $path)

This creates a new DBus object with an path of C<$path>
registered within the service C<$service>. The C<$path>
parameter should be a string complying with the usual
DBus requirements for object paths, while the C<$service>
parameter should be an instance of L<Net::DBus::Service>.
The latter is typically obtained by calling the C<export_service>
method on the L<Net::DBus> object.

=item my $object = Net::DBus::BaseObject->new($parentobj, $subpath)

This creates a new DBus child object with an path of C<$subpath>
relative to its parent C<$parentobj>. The C<$subpath>
parameter should be a string complying with the usual
DBus requirements for object paths, while the C<$parentobj>
parameter should be an instance of L<Net::DBus::BaseObject>.

=cut

sub new {
    my $class = shift;
    my $self = {};

    my $parent = shift;
    my $path = shift;

    $path =~ s{/$}{} unless $path eq '/';

    $self->{parent} = $parent;
    if ($parent->isa(__PACKAGE__)) {
	$path =~ s{^/}{};
	$self->{service} = $parent->get_service;
	$self->{object_path} = $parent->get_object_path;
	$self->{object_path} .= '/' unless $self->{object_path} =~ m{/$};
	$self->{object_path} .= $path;
    } else {
	$path = "/$path" unless $path =~ m{^/};
	$self->{service} = $parent;
	$self->{object_path} = $path;
    }

    $self->{interface} = shift;
    $self->{introspector} = undef;
    $self->{introspected} = 0;
    $self->{callbacks} = {};
    $self->{children} = {};

    bless $self, $class;

    if ($self->{parent}->isa(__PACKAGE__)) {
	$self->{parent}->_register_child($self);
    } else {
	$self->get_service->_register_object($self);
    }

    return $self;
}


=item $object->disconnect();

This method disconnects the object from the bus, such that it
will no longer receive messages sent by other clients. Any
child objects will be recursively disconnected too. After an
object has been disconnected, it is possible for Perl to
garbage collect the object instance. It will also make it
possible to connect a newly created object to the same path.

=cut

sub disconnect {
    my $self = shift;

    return unless $self->{parent};

    foreach my $child (keys %{$self->{children}}) {
	$self->_unregister_child($self->{children}->{$child});
    }

    if ($self->{parent}->isa(__PACKAGE__)) {
	$self->{parent}->_unregister_child($self);
    } else {
	$self->get_service->_unregister_object($self);
    }
    $self->{parent} = undef;
}

=item my $bool = $object->is_connected

Returns a true value if the object is connected to the bus,
and thus capable of being accessed by remote clients. Returns
false if the object is disconnected & thus ready for garbage
collection. All objects start off in the connected state, and
will only transition if the C<disconnect> method is called.

=cut

sub is_connected {
    my $self = shift;

    return 0 unless $self->{parent};

    if ($self->{parent}->isa(__PACKAGE__)) {
	return $self->{parent}->is_connected;
    }
    return 1;
}

sub DESTROY {
    my $self = shift;
    # XXX there are some issues during global
    # destruction which need to be better figured
    # out before this will work
    #$self->disconnect;
}

sub _register_child {
    my $self = shift;
    my $object = shift;

    $self->get_service->_register_object($object);
    $self->{children}->{$object->get_object_path} = $object;
}


sub _unregister_child {
    my $self = shift;
    my $object = shift;

    $self->get_service->_unregister_object($object);
    delete $self->{children}->{$object->get_object_path};
}

# return a list of sub nodes for this object
sub _get_sub_nodes {
    my $self = shift;
    my %uniq;

    my $base = $self->{object_path};
    $base .= '/' if $base ne '/';
    foreach ( keys( %{$self->{children}} ) ) {
      m/^$base([^\/]+)/;
      $uniq{$1} = 1;
    }

    return sort( keys( %uniq ) );
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

=item $object->emit_signal_in($name, $interface, $client, @args);

Emits a signal from the object, with a name of C<$name>. If the
C<$interface> parameter is defined, the signal will be scoped
within that interface. If the C<$client> parameter is defined,
the signal will be unicast to that client on the bus. The
signal and the data types of the arguments C<@args> must have
been registered with L<Net::DBus::Exporter> by calling the
C<dbus_signal> method.

=cut

sub emit_signal_in {
    my $self = shift;
    my $name = shift;
    my $interface = shift;
    my $destination = shift;
    my @args = @_;

    die "object is disconnected from the bus" unless $self->is_connected;

    my $con = $self->get_service->get_bus->get_connection;

    my $signal = $con->make_signal_message($self->get_object_path,
					   $interface,
					   $name);
    if ($destination) {
	$signal->set_destination($destination);
    }

    my $ins = $self->_introspector;
    if ($ins) {
	$ins->encode($signal, "signals", $name, "params", @args);
    } else {
	$signal->append_args_list(@args);
    }
    $con->send($signal);

    # Short circuit locally registered callbacks
    if (exists $self->{callbacks}->{$interface} &&
	exists $self->{callbacks}->{$interface}->{$name}) {
	my $cb = $self->{callbacks}->{$interface}->{$name};
	&$cb(@args);
    }
}

=item $self->emit_signal_to($name, $client, @args);

Emits a signal from the object, with a name of C<$name>. The
signal and the data types of the arguments C<@args> must have
been registered with L<Net::DBus::Exporter> by calling the
C<dbus_signal> method. The signal will be sent only to the
client named by the C<$client> parameter.

=cut

sub emit_signal_to {
    my $self = shift;
    my $name = shift;
    my $destination = shift;
    my @args = @_;

    my $intro = $self->_introspector;
    if (!$intro) {
	die "no introspection data available for '" . $self->get_object_path .
	    "', use the emit_signal_in method instead";
    }
    my @interfaces = $intro->has_signal($name);
    if ($#interfaces == -1) {
	die "no signal with name '$name' is exported in object '" .
	    $self->get_object_path . "'\n";
    } elsif ($#interfaces > 0) {
	die "signal '$name' is exported in more than one interface of '" .
	    $self->get_object_path . "', use the emit_signal_in method instead.";
    }
    $self->emit_signal_in($name, $interfaces[0], $destination, @args);
}

=item $self->emit_signal($name, @args);

Emits a signal from the object, with a name of C<$name>. The
signal and the data types of the arguments C<@args> must have
been registered with L<Net::DBus::Exporter> by calling the
C<dbus_signal> method. The signal will be broadcast to all
clients on the bus.

=cut

sub emit_signal {
    my $self = shift;
    my $name = shift;
    my @args = @_;

    $self->emit_signal_to($name, undef, @args);
}

=item $object->connect_to_signal_in($name, $interface, $coderef);

Connects a callback to a signal emitted by the object. The C<$name>
parameter is the name of the signal within the object, and C<$coderef>
is a reference to an anonymous subroutine. When the signal C<$name>
is emitted by the remote object, the subroutine C<$coderef> will be
invoked, and passed the parameters from the signal. The C<$interface>
parameter is used to specify the explicit interface defining the
signal to connect to.

=cut

sub connect_to_signal_in {
    my $self = shift;
    my $name = shift;
    my $interface = shift;
    my $code = shift;

    die "object is disconnected from the bus" unless $self->is_connected;

    $self->{callbacks}->{$interface} = {} unless
	exists $self->{callbacks}->{$interface};
    $self->{callbacks}->{$interface}->{$name} = $code;
}

=item $object->connect_to_signal($name, $coderef);

Connects a callback to a signal emitted by the object. The C<$name>
parameter is the name of the signal within the object, and C<$coderef>
is a reference to an anonymous subroutine. When the signal C<$name>
is emitted by the remote object, the subroutine C<$coderef> will be
invoked, and passed the parameters from the signal.

=cut

sub connect_to_signal {
    my $self = shift;
    my $name = shift;
    my $code = shift;

    my $ins = $self->_introspector;
    if (!$ins) {
	die "no introspection data available for '" . $self->get_object_path .
	    "', use the connect_to_signal_in method instead";
    }
    my @interfaces = $ins->has_signal($name);

    if ($#interfaces == -1) {
	die "no signal with name '$name' is exported in object '" .
	    $self->get_object_path . "'\n";
    } elsif ($#interfaces > 0) {
	die "signal with name '$name' is exported " .
	    "in multiple interfaces of '" . $self->get_object_path . "'" .
	    "use the connect_to_signal_in method instead";
    }

    $self->connect_to_signal_in($name, $interfaces[0], $code);
}


sub _dispatch {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    my $reply;
    my $method_name = $message->get_member;
    my $interface = $message->get_interface;
    if ((defined $interface) &&
        ($interface eq "org.freedesktop.DBus.Introspectable")) {
	if ($method_name eq "Introspect" &&
	    $self->_introspector &&
	    $ENABLE_INTROSPECT) {
	    if ($message->get_args_list) {
		$reply = $connection->make_error_message($message,
							 "org.freedesktop.DBus.Error.Failed",
							 "too many parameters for method 'Introspect'");
	    } else {
	    my $xml = $self->_introspector->format($self);
	    $reply = $connection->make_method_return_message($message);

	    $self->_introspector->encode($reply, "methods", $method_name, "returns", $xml);
	    }
	}
    } elsif ((defined $interface) &&
	     ($interface eq "org.freedesktop.DBus.Properties")) {
	if ($method_name eq "Get") {
	    $reply = $self->_dispatch_prop_read($connection, $message);
	} elsif ($method_name eq "GetAll") {
	    $reply = $self->_dispatch_all_prop_read($connection, $message);
	} elsif ($method_name eq "Set") {
	    $reply = $self->_dispatch_prop_write($connection, $message);
	}
    } else {
	$reply = $self->_dispatch_object($connection, $message);
    }

    if (!$reply) {
	$reply = $connection->make_error_message($message,
						 "org.freedesktop.DBus.Error.UnknownMethod",
						 "No such method " . ref($self) . "->" . $method_name);
    }

    if ($message->get_no_reply()) {
	# Not sending reply
    } else {
	$self->get_service->get_bus->get_connection->send($reply);
    }
}


=item $reply = $object->_dispatch_object($connection, $message);

The C<_dispatch_object> method is to be used to handle dispatch of
methods implemented by the object. The default implementation is
a no-op and should be overridden by subclasses todo whatever
processing is required. If the C<$message> could be handled then
another C<Net::DBus::Binding::Message> instance should be returned
for the reply. If C<undef> is returned, then a generic error will
be returned to the caller.

=cut

sub _dispatch_object {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    return 0;
}


=item $currvalue = $object->_dispatch_property($name);
=item $object->_dispatch_property($name, $newvalue);

The C<_dispatch_property> method is to be used to handle dispatch
of property reads and writes. The C<$name> parameter is the name
of the property being accessed. If C<$newvalue> is supplied then
the property is to be updated, otherwise the current value is to
be returned. The default implementation will simply raise an
error, so must be overridden in subclasses.

=cut

sub _dispatch_property {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    die "No method for property $name";
}


sub _dispatch_prop_read {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    my $ins = $self->_introspector;

    if (!$ins) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no introspection data exported for properties");
    }

    my ($pinterface, $pname, @pargs) = eval { $ins->decode($message, "methods", "Get", "params") };
    if ($@) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "$@");
    }
    if (@pargs) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "too many parameters for method 'Get'");
    }
    if (not defined $pinterface) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no interface was specified");
    }
    if (not defined $pname) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no property was specified for interface '$pinterface'");
    }

    if (!$ins->has_property($pname, $pinterface)) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no property '$pname' exported in interface '$pinterface'");
    }

    if (!$ins->is_property_readable($pinterface, $pname)) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "property '$pname' in interface '$pinterface' is not readable");
    }

    my $value = eval {
	$self->_dispatch_property($pname);
    };
    if ($@) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "error reading '$pname' in interface '$pinterface': $@");
    } else {
	my $reply = $connection->make_method_return_message($message);
	
	$self->_introspector->encode($reply, "methods", "Get", "returns", $value);
	return $reply;
    }
}

sub _dispatch_all_prop_read {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    my $ins = $self->_introspector;

    if (!$ins) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no introspection data exported for properties");
    }

    my ($pinterface, @pargs) = eval { $ins->decode($message, "methods", "GetAll", "params") };
    if ($@) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "$@");
    }
    if (@pargs) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "too many parameters for method 'GetAll'");
    }
    if (not defined $pinterface) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no interface was specified");
    }

    my %values = ();
    foreach my $pname ($ins->list_properties($pinterface)) {
    	unless ($ins->is_property_readable($pinterface, $pname)) {
		next; # skip write-only properties
	}

	$values{$pname} = eval {
	    $self->_dispatch_property($pname);
	};
	if ($@) {
	    return $connection->make_error_message($message,
						   "org.freedesktop.DBus.Error.Failed",
						   "error reading '$pname' in interface '$pinterface': $@");
	}
    }

    my $reply = $connection->make_method_return_message($message);

    $self->_introspector->encode($reply, "methods", "GetAll", "returns", \%values);
    return $reply;
}

sub _dispatch_prop_write {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    my $ins = $self->_introspector;

    if (!$ins) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no introspection data exported for properties");
    }

    my ($pinterface, $pname, $pvalue, @pargs) = eval { $ins->decode($message, "methods", "Set", "params") };
    if ($@) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "$@");
    }
    if (@pargs) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "too many parameters for method 'Set'");
    }
    if (not defined $pinterface) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no interface was specified");
    }
    if (not defined $pname) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no property was specified for interface '$pinterface'");
    }
    if (not defined $pvalue) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no value was specified for property '$pname' in interface '$pinterface'");
    }

    if (!$ins->has_property($pname, $pinterface)) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "no property '$pname' exported in interface '$pinterface'");
    }

    if (!$ins->is_property_writable($pinterface, $pname)) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "property '$pname' in interface '$pinterface' is not writable");
    }

    eval {
	$self->_dispatch_property($pname, $pvalue);
    };
    if ($@) {
	return $connection->make_error_message($message,
					       "org.freedesktop.DBus.Error.Failed",
					       "error writing '$pname' in interface '$pinterface': $@");
    } else {
	return $connection->make_method_return_message($message);
    }
}


sub _introspector {
    my $self = shift;

    if (!$self->{introspected}) {
	$self->{introspector} = Net::DBus::Exporter::_dbus_introspector(ref($self));
	$self->{introspected} = 1;
    }
    return $self->{introspector};
}

1;


=pod

=back

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2005-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Service>, L<Net::DBus::Object>,
L<Net::DBus::ProxyObject>, L<Net::DBus::Exporter>,
L<Net::DBus::RemoteObject>

=cut
