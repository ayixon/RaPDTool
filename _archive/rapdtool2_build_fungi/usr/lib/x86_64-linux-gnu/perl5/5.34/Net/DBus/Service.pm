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

Net::DBus::Service - Provide a service to the bus for clients to use

=head1 SYNOPSIS

  package main;

  use Net::DBus;

  # Attach to the bus
  my $bus = Net::DBus->find;

  # Acquire a service 'org.demo.Hello'
  my $service = $bus->export_service("org.demo.Hello");

  # Export our object within the service
  my $object = Demo::HelloWorld->new($service);

  ....rest of program...

=head1 DESCRIPTION

This module represents a service which is exported to the message
bus. Once a service has been exported, it is possible to create
and export objects to the bus.

=head1 METHODS

=over 4

=cut


package Net::DBus::Service;

use 5.006;
use strict;
use warnings;

=item my $service = Net::DBus::Service->new($bus, $name);

Create a new service, attaching to the bus provided in
the C<$bus> parameter, which should be an instance of
the L<Net::DBus> object. The C<$name> parameter is the
qualified service name. It is not usually necessary to
use this constructor, since services can be created via
the C<export_service> method on the L<Net::DBus> object.

When C<$name> is not specified or is C<undef> then returned
handle to the service is identified only by the unique name
of client's connection to the bus.

=cut

sub new {
    my $class = shift;
    my $self = {};

    $self->{bus} = shift;
    $self->{service_name} = shift;
    $self->{objects} = {};

    bless $self, $class;

    if (not defined $self->get_service_name) {
        $self->{service_name} = $self->get_bus->get_unique_name;
        return $self;
    }

    $self->get_bus->get_connection->request_name($self->get_service_name);

    return $self;
}

=item my $bus = $service->get_bus;

Retrieves the L<Net::DBus> object to which this service is
attached.

=cut

sub get_bus {
    my $self = shift;
    return $self->{bus};
}

=item my $name = $service->get_service_name

Retrieves the qualified name by which this service is
known on the bus.

=cut

sub get_service_name {
    my $self = shift;
    return $self->{service_name};
}


sub _register_object {
    my $self = shift;
    my $object = shift;
    #my $wildcard = shift || 0;

#    if ($wildcard) {
#	$self->get_bus->get_connection->
#	    register_fallback($object->get_object_path,
#			      sub {
#				  $object->_dispatch(@_);
#			      });
#    } else {
	$self->get_bus->get_connection->
	    register_object_path($object->get_object_path,
				 sub {
				     $object->_dispatch(@_);
				 });
#    }
}


sub _unregister_object {
    my $self = shift;
    my $object = shift;

    $self->get_bus->get_connection->
	unregister_object_path($object->get_object_path);
}

1;

=pod

=back

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2005-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Object>, L<Net::DBus::RemoteService>

=cut
