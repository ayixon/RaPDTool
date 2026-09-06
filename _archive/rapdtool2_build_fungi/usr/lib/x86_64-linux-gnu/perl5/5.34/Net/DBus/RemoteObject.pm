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

Net::DBus::RemoteObject - Access objects provided on the bus

=head1 SYNOPSIS

  my $service = $bus->get_service("org.freedesktop.DBus");
  my $object = $service->get_object("/org/freedesktop/DBus");

  print "Names on the bus {\n";
  foreach my $name (sort @{$object->ListNames}) {
      print "  ", $name, "\n";
  }
  print "}\n";

=head1 DESCRIPTION

This module provides the API for accessing remote objects available
on the bus. It uses the autoloader to fake the presence of methods
based on the API of the remote object. There is also support for
setting callbacks against signals, and accessing properties of the
object.

=head1 METHODS

=over 4

=cut

package Net::DBus::RemoteObject;

use 5.006;
use strict;
use warnings;

our $AUTOLOAD;

use Net::DBus::Binding::Introspector;
use Net::DBus::ASyncReply;
use Net::DBus::Annotation qw(:call);

#
# BEGIN WARNING
#
# Each method added to this module prevents an application from
# being able to invoke a similarly named method on a remote object.
#
# As such the aim is that no further public methods should be
# added. All private methods should have a _net_dbus_ prefix on
# them too.
#
# END WARNING
#


=item my $object = Net::DBus::RemoteObject->new($service, $object_path[, $interface], \%params);

Creates a new handle to a remote object. The C<$service> parameter is an instance
of the L<Net::DBus::RemoteService> method, and C<$object_path> is the identifier of
an object exported by this service, for example C</org/freedesktop/DBus>. For remote
objects which implement more than one interface it is possible to specify an optional
name of an interface as the third parameter. This is only really required, however, if
two interfaces in the object provide methods with the same name, since introspection
data can be used to automatically resolve the correct interface to call cases where
method names are unique. Rather than using this constructor directly, it is preferable
to use the C<get_object> method on L<Net::DBus::RemoteService>, since this caches handles
to remote objects, eliminating unnecessary introspection data lookups.

The C<%params> parameter contains extra configuration parameters for the object. Currently
a single parameter is supported, C<timeout> which takes a value in milliseconds to use as
the timeout for method calls on the object.

=cut


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    $self->{service} = shift;
    $self->{object_path}  = shift;
    $self->{interface} = @_ ? shift : undef;
    $self->{interfaces} = {};
    $self->{introspected} = 0;
    $self->{signal_handlers} = {};
    $self->{signal_id} = 0;

    my %params = @_;
    $self->{timeout} = $params{timeout};

    bless $self, $class;

    return $self;
}

=item my $object = $object->as_interface($interface);

Casts the object to a specific interface, returning a new instance of the
L<Net::DBus::RemoteObject> specialized to the desired interface. It is only
necessary to cast objects to a specific interface, if two interfaces
export methods or signals with the same name, or the remote object does not
support introspection.

=cut

sub as_interface {
    my $self = shift;
    my $interface = shift;

    die "already cast to " . $self->{interface} . "'"
	if $self->{interface};

    unless (exists $self->{interfaces}->{$interface}) {
	$self->{interfaces}->{$interface} = 
	    $self->new($self->{service},
		       $self->{object_path},
		       $interface);
    }
    return $self->{interfaces}->{$interface};
}

=item my $service = $object->get_service

Retrieves a handle for the remote service on which this object is
attached. The returned object is an instance of L<Net::DBus::RemoteService>

=cut

sub get_service {
    my $self = shift;
    return $self->{service};
}

=item my $path = $object->get_object_path

Retrieves the unique path identifier for this object within the
service.

=cut

sub get_object_path {
    my $self = shift;
    return $self->{object_path};
}

=item my $object = $object->get_child_object($subpath, [$interface])

Retrieves a handle to a child of this object, identified
by the relative path C<$subpath>. The returned object
is an instance of C<Net::DBus::RemoteObject>. The optional
C<$interface> parameter can be used to immediately cast
the object to a specific type.

=cut

sub get_child_object {
    my $self = shift;
    my $path = shift;
    my $interface = @_ ? shift : undef;
    my $fullpath = $self->{object_path} . $path;

    return $self->new($self->get_service,
		      $fullpath,
		      $interface);
}

sub _net_dbus_introspector {
    my $self = shift;


    unless ($self->{introspected}) {
	my $con = $self->{service}->get_bus()->get_connection();

	my $call = $con->make_method_call_message($self->{service}->get_service_name(),
						  $self->{object_path},
						  "org.freedesktop.DBus.Introspectable",
						  "Introspect");

	my $xml = eval {
	    my $reply = $con->send_with_reply_and_block($call, 60 * 1000);

	    my $iter = $reply->iterator;
	    return $iter->get(&Net::DBus::Binding::Message::TYPE_STRING);
	};
	if ($@) {
	    if (UNIVERSAL::isa($@, "Net::DBus::Error") &&
		($@->{name} eq "org.freedesktop.DBus.Error.ServiceUnknown" ||
		$@->{name} eq "org.freedesktop.DBus.Error.NoReply")) {
		die $@;
	    } else {
		# Ignore other failures, since its probably
		# just that the object doesn't implement
		# the introspect method. Of course without
		# the introspect method we can't tell for sure
		# if this is the case..
		#warn "could not introspect object: $@";
	    }
	}
	if ($xml) {
	    $self->{introspector} = Net::DBus::Binding::Introspector->new(xml => $xml,
									  object_path => $self->{object_path});
	}
	$self->{introspected} = 1;
    }
    return $self->{introspector};
}


=item my $sigid = $object->connect_to_signal($name, $coderef);

Connects a callback to a signal emitted by the object. The C<$name>
parameter is the name of the signal within the object, and C<$coderef>
is a reference to an anonymous subroutine. When the signal C<$name>
is emitted by the remote object, the subroutine C<$coderef> will be
invoked, and passed the parameters from the signal. A unique C<$sigid>
will be returned, which can be later passed to C<disconnect_from_signal>
to remove the handler

=cut

sub connect_to_signal {
    my $self = shift;
    my $name = shift;
    my $code = shift;

    my $ins = $self->_net_dbus_introspector;
    my $interface = $self->{interface};
    if (!$interface) {
	if (!$ins) {
	    die "no introspection data available for '" . $self->get_object_path .
		"', and object is not cast to any interface";
	}
	my @interfaces = $ins->has_signal($name);

	if ($#interfaces == -1) {
	    die "no signal with name '$name' is exported in object '" .
		$self->get_object_path . "'\n";
	} elsif ($#interfaces > 0) {
	    warn "signal with name '$name' is exported " .
		"in multiple interfaces of '" . $self->get_object_path . "'" .
		"connecting to first interface only\n";
	}
	$interface = $interfaces[0];
    }

    if ($ins &&
	$ins->has_signal($name, $interface) &&
	$ins->is_signal_deprecated($name, $interface)) {
	warn "signal $name in interface $interface on " . $self->get_object_path . " is deprecated";
    }

    my $cb = sub {
	my $signal = shift;
	my $ins = $self->_net_dbus_introspector;
	my @params;
	if ($ins) {
	    @params = $ins->decode($signal, "signals", $signal->get_member, "params");
	} else {
	    @params = $signal->get_args_list;
	}

	foreach my $handler (@{$self->{signal_handlers}->{$signal->get_member}->{handlers}}) {
	    my ($id, $cb) = @{$handler};
	    &$cb(@params);
	}
    };
    if (!exists $self->{signal_handlers}->{$name}) {
	$self->{signal_handlers}->{$name} = { cb => $cb, handlers => [] };
	$self->get_service->
	    get_bus()->
	    _add_signal_receiver($cb,
				 $name,
				 $interface,
				 $self->{service}->get_service_name(),
				 $self->{object_path});
    }
    my $sigid = ++$self->{signal_id};
    push @{$self->{signal_handlers}->{$name}->{handlers}}, [$sigid, $code];
    return $sigid;
}


=item $object->disconnect_from_signal($name, $sigid);

Disconnects from a signal emitted by the object. The C<$name>
parameter is the name of the signal within the object. The
C<$sigid> must be the unique signal handler ID returned by
a previous C<connect_to_signal> method call.

=cut

sub disconnect_from_signal {
    my $self = shift;
    my $name = shift;
    my $sigid = shift;

    my $ins = $self->_net_dbus_introspector;
    my $interface = $self->{interface};
    if (!$interface) {
	if (!$ins) {
	    die "no introspection data available for '" . $self->get_object_path .
		"', and object is not cast to any interface";
	}
	my @interfaces = $ins->has_signal($name);

	if ($#interfaces == -1) {
	    die "no signal with name '$name' is exported in object '" .
		$self->get_object_path . "'\n";
	} elsif ($#interfaces > 0) {
	    warn "signal with name '$name' is exported " .
		"in multiple interfaces of '" . $self->get_object_path . "'" .
		"connecting to first interface only\n";
	}
	$interface = $interfaces[0];
    }

    my @handlers;
    foreach my $handler (@{$self->{signal_handlers}->{$name}->{handlers}}) {
	my ($thissigid, $cb) = @{$handler};
	if ($thissigid != $sigid) {
	    push @handlers, $handler;
	}
    }
    if (@handlers) {
	$self->{signal_handlers}->{$name}->{handlers} = \@handlers;
    } else {
	$self->get_service->
	    get_bus()->
	    _remove_signal_receiver($self->{signal_handlers}->{$name}->{cb},
				    $name,
				    $interface,
				    $self->{service}->get_service_name(),
				    $self->{object_path});
	delete $self->{signal_handlers}->{$name};
    }
}


sub DESTROY {
    # No op merely to stop AutoLoader trying to
    # call DESTROY on remote object
}

sub _net_dbus_timeout {
    my $self = shift;

    if (defined $self->{timeout}) {
	return $self->{timeout};
    }
    if (defined $self->get_service()->timeout()) {
	return $self->get_service()->timeout();
    }
    return $self->get_service()->get_bus()->timeout();
}


sub AUTOLOAD {
    my $self = shift;
    my $sub = $AUTOLOAD;

    my $mode = dbus_call_sync;
    my $timeout;

    while (@_ && UNIVERSAL::isa($_[0], "Net::DBus::Annotation")) {
	if ($_[0] eq dbus_call_sync ||
	    $_[0] eq dbus_call_async ||
	    $_[0] eq dbus_call_noreply) {
	    $mode = shift;
	} elsif ($_[0] eq dbus_call_timeout) {
	    shift;
	    $timeout = shift;
	} else {
	    die "Unknown annotation $_[0]";
	}
    }
    $timeout = $self->_net_dbus_timeout() unless defined $timeout;

    (my $name = $AUTOLOAD) =~ s/.*:://;

    my $interface = $self->{interface};

    # If introspection data is available, use that
    # to resolve correct interface (if object is not
    # cast to an explicit interface already)
    my $ins = $self->_net_dbus_introspector();
    if ($ins) {
	if ($interface) {
	    if ($ins->has_method($name, $interface)) {
		return $self->_net_dbus_call_method($mode, $timeout,
						    $name, $interface, 1,
						    @_);
	    }
	    if ($ins->has_property($name, $interface)) {
		if ($ins->is_property_deprecated($name, $interface)) {
		    warn "property $name in interface $interface on " . $self->get_object_path . " is deprecated";
		}

		if (@_) {
		    $self->_net_dbus_call_method($mode, $timeout,
						 "Set", "org.freedesktop.DBus.Properties", 1,
						 $interface, $name, $_[0]);
		    return ();
		} else {
		    return $self->_net_dbus_call_method($mode, $timeout,
							"Get", "org.freedesktop.DBus.Properties", 1,
							$interface, $name);
		}
	    }
	} else {
	    my @interfaces = $ins->has_method($name);

	    if (@interfaces) {
		if ($#interfaces > 0) {
		    die "method with name '$name' is exported " .
			"in multiple interfaces of '" . $self->get_object_path . "'";
		}
		return $self->_net_dbus_call_method($mode, $timeout,
						    $name, $interfaces[0], 1, @_);
	    }
	    @interfaces = $ins->has_property($name);

	    if (@interfaces) {
		if ($#interfaces > 0) {
		    die "property with name '$name' is exported " .
			"in multiple interfaces of '" . $self->get_object_path . "'";
		}
		$interface = $interfaces[0];
		if ($ins->is_property_deprecated($name, $interface)) {
		    warn "property $name in interface $interface on " . $self->get_object_path . " is deprecated";
		}
		if (@_) {
		    $self->_net_dbus_call_method($mode, $timeout,
						 "Set", "org.freedesktop.DBus.Properties", 1,
						 $interface, $name, $_[0]);
		    return ();
		} else {
		    return $self->_net_dbus_call_method($mode, $timeout,
							"Get", "org.freedesktop.DBus.Properties", 1,
							$interface, $name);
		}
	    }
	}
    }

    if (!$interface) {
	die "no introspection data available for method '" . $name . "' in object '" .
	    $self->get_object_path . "', and object is not cast to any interface";
    }

    return $self->_net_dbus_call_method($mode, $timeout,
					$name, $interface,
					0, @_);
}


sub _net_dbus_call_method {
    my $self = shift;
    my $mode = shift;
    my $timeout = shift;
    my $name = shift;
    my $interface = shift;
    my $introspect = shift;

    my $con = $self->{service}->get_bus()->get_connection();

    my $ins = $introspect ? $self->_net_dbus_introspector : undef;
    if ($ins &&
	$ins->is_method_deprecated($name, $interface)) {
	warn "method '$name' in interface $interface on object " . $self->get_object_path . " is deprecated\n";
    }

    my $call = $con->make_method_call_message($self->{service}->get_service_name(),
					      $self->{object_path},
					      $interface,
					      $name);

    #$call->set_destination($self->get_service->get_owner_name);

    if ($ins) {
	$ins->encode($call, "methods", $name, "params", @_);
    } else {
	$call->append_args_list(@_);
    }

    if ($mode == dbus_call_sync) {
	my $reply = $con->
	    send_with_reply_and_block($call, $timeout);

	my @reply;
	if ($ins) {
	    @reply = $ins->decode($reply, "methods", $name, "returns");
	} else {
	    @reply = $reply->get_args_list;
	}

	return wantarray ? @reply : $reply[0];
    } elsif ($mode == dbus_call_async) {
	my $pending_call = $self->{service}->
	    get_bus()->
	    get_connection()->
	    send_with_reply($call, $timeout);
	my $reply = Net::DBus::ASyncReply->_new(pending_call => $pending_call,
						($ins ? (introspector => $ins,
							 method_name => $name)
						 : ()));
	return $reply;
    } elsif ($mode == dbus_call_noreply) {
	$call->set_no_reply(1);
	$self->{service}->
	    get_bus()->
	    get_connection()->
	    send($call, $timeout);
    } else {
	die "unsupported annotation '$mode'";
    }
}


1;

=pod

=back

=head1 AUTHOR

Daniel Berrange <dan@berrange.com>

=head1 COPYRIGHT

Copright (C) 2004-2011, Daniel Berrange.

=head1 SEE ALSO

L<Net::DBus::RemoteService>, L<Net::DBus::Object>, L<Net::DBus::Annotation>

=cut
