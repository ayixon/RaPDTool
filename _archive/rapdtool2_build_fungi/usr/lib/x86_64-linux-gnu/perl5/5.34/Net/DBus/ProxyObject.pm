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

Net::DBus::ProxyObject - Implement objects to export to the bus

=head1 SYNOPSIS

  # Connecting an object to the bus, under a service
  package main;

  use Net::DBus;

  # Attach to the bus
  my $bus = Net::DBus->find;

  # Create our application's object instance
  my $object = Demo::HelloWorld->new()

  # Acquire a service 'org.demo.Hello'
  my $service = $bus->export_service("org.demo.Hello");

  # Finally export the object to the bus
  my $proxy = Demo::HelloWorld::DBus->new($object);

  ....rest of program...


  # Define a new package for the object we're going
  # to export
  package Demo::HelloWorld;

  sub new {
      my $class = shift;
      my $service = shift;
      my $self = {};

      $self->{sighandler} = undef;

      bless $self, $class;

      return $self;
  }

  sub sighandler {
      my $self = shift;
      my $callback = shift;

      $self->[sighandler} = $callback;
  }

  sub Hello {
    my $self = shift;
    my $name = shift;

    &{$self->{sighandler}}("Greeting", "Hello $name");
    return "Said hello to $name";
  }

  sub Goodbye {
    my $self = shift;
    my $name = shift;

    &{$self->{sighandler}}("Greeting", "Goodbye $name");
    return "Said goodbye to $name";
  }


  # Define a new package for the object we're going
  # to export
  package Demo::HelloWorld::DBus;

  # Specify the main interface provided by our object
  use Net::DBus::Exporter qw(org.example.demo.Greeter);

  # We're going to be a DBus object
  use base qw(Net::DBus::ProxyObject);

  # Export a 'Greeting' signal taking a stringl string parameter
  dbus_signal("Greeting", ["string"]);

  # Export 'Hello' as a method accepting a single string
  # parameter, and returning a single string value
  dbus_method("Hello", ["string"], ["string"]);

  sub new {
      my $class = shift;
      my $service = shift;
      my $impl = shfit;
      my $self = $class->SUPER::new($service, "/org/demo/HelloWorld", $impl);

      bless $self, $class;

      $self->sighandler(sub {
	  my $signame = shift;
	  my $arg = shift;
	  $self->emit_signal($signame, $arg);
      });

      return $self;
  }

  # Export 'Goodbye' as a method accepting a single string
  # parameter, and returning a single string, but put it
  # in the 'org.exaple.demo.Farewell' interface

  dbus_method("Goodbye", ["string"], ["string"], "org.example.demo.Farewell");

=head1 DESCRIPTION

This the base for creating a proxy between a bus object and an
application's object. It allows the application's object model
to remain separate from the RPC object model. The proxy object
will forward method calls from the bus, to the implementation
object. The proxy object can also register callbacks against
the application object, which it can use to then emit signals
on the bus.

=head1 METHODS

=over 4

=cut

package Net::DBus::ProxyObject;

use 5.006;
use strict;
use warnings;
use base qw(Net::DBus::BaseObject);

=item my $object = Net::DBus::ProxyObject->new($service, $path, $impl)

This creates a new DBus object with an path of C<$path>
registered within the service C<$service>. The C<$path>
parameter should be a string complying with the usual
DBus requirements for object paths, while the C<$service>
parameter should be an instance of L<Net::DBus::Service>.
The latter is typically obtained by calling the C<export_service>
method on the L<Net::DBus> object. The C<$impl> parameter is
the application object which will implement the methods being
exported to the bus.

=item my $object = Net::DBus::ProxyObject->new($parentobj, $subpath, $impl)

This creates a new DBus child object with an path of C<$subpath>
relative to its parent C<$parentobj>. The C<$subpath>
parameter should be a string complying with the usual
DBus requirements for object paths, while the C<$parentobj>
parameter should be an instance of L<Net::DBus::BaseObject> or
a subclass. The C<$impl> parameter is the application object
which will implement the methods being exported to the bus.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my ($serviceOrParent, $path, $impl) = @_;

    $self->{impl} = $impl;

    bless $self, $class;

    return $self;
}


sub _dispatch_object {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    my $reply;
    my $method_name = $message->get_member;
    my $interface = $message->get_interface;
    if ($self->_is_method_allowed($method_name)) {
	my $ins = $self->_introspector;
	my @ret = eval {
	    my @args;
	    if ($ins) {
		if (defined $interface and not $ins->has_interface($interface)) {
		    die Net::DBus::Error->new(name => 'org.freedesktop.DBus.Error.UnknownMethod',
			message => "object does not provide interface '$interface'");
		}
		@args = $ins->decode($message, "methods", $method_name, "params");
		($interface) = $ins->has_method($method_name) unless defined $interface;
		if (defined $interface && scalar @args != scalar $ins->get_method_params($interface, $method_name)) {
		    die Net::DBus::Error->new(name => 'org.freedesktop.DBus.Error.Failed',
			message => "incorrect number of parameters for method '$method_name' in interface '$interface'");
		}
	    } else {
		@args = $message->get_args_list;
	    }

	    $self->{impl}->$method_name(@args);
	};
	if ($@) {
	    my $name = UNIVERSAL::isa($@, "Net::DBus::Error") ? $@->name : "org.freedesktop.DBus.Error.Failed";
	    my $desc = UNIVERSAL::isa($@, "Net::DBus::Error") ? $@->message : $@;
	    $reply = $connection->make_error_message($message,
						     $name,
						     $desc);
	} else {
	    $reply = $connection->make_method_return_message($message);
	    if ($ins) {
		$self->_introspector->encode($reply, "methods", $method_name, "returns", @ret);
	    } else {
		$reply->append_args_list(@ret);
	    }
	}
    }

    return $reply;
}


sub _dispatch_property {
    my $self = shift;
    my $name = shift;

    if (!$self->{impl}->can($name)) {
	die "no method to for property '$name'";
    }

    return $self->{impl}->$name(@_);
}


sub _is_method_allowed {
    my $self = shift;
    my $method = shift;

    # If this object instance doesn't have it defined, trivially can't
    # allow it
    return 0 unless $self->{impl}->can($method);

    my $ins = $self->_introspector;
    if (defined $ins) {
	# Finally do check against introspection data
	return $ins->is_method_allowed($method);
    }

    # No introspector, so have to assume its allowed
    return 1;
}

1;


=pod

=back

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2005-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Service>, L<Net::DBus::BaseObject>,
L<Net::DBus::ProxyObject>, L<Net::DBus::Exporter>,
L<Net::DBus::RemoteObject>

=cut
