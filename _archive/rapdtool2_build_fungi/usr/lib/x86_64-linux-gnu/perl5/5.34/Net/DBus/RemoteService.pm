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

Net::DBus::RemoteService - Access services provided on the bus

=head1 SYNOPSIS

  my $bus = Net::DBus->find;
  my $service = $bus->get_service("org.freedesktop.DBus");

  my $object = $service->get_object("/org/freedesktop/DBus");
  foreach (@{$object->ListNames}) {
    print "$_\n";
  }

=head1 DESCRIPTION

This object provides a handle to a remote service on the
bus. From this handle it is possible to access objects
associated with the service. If a service is not running,
an attempt will be made to activate it the first time a
method is called against one of its objects.

=head1 METHODS

=over 4

=cut

package Net::DBus::RemoteService;

use 5.006;
use strict;
use warnings;

use Net::DBus::RemoteObject;

=item my $service = Net::DBus::RemoteService->new($bus, $owner, $service_name);

Creates a new handle for a remote service. The C<$bus> parameter is an
instance of L<Net::DBus>, C<$owner> is the name of the client providing the
service, while C<$service_name> is the well known name of the  service on
the bus. Service names consist of two or more tokens, separated
by periods, while the tokens comprise the letters a-z, A-Z, 0-9 and _,
for example C<org.freedesktop.DBus>. There is generally no need to call
this constructor, instead the C<get_service> method on L<Net::DBus> should
be used. This caches handles to remote services, eliminating repeated
retrieval of introspection data.

=cut

sub new {
    my $class = shift;
    my $self = {};

    $self->{bus} = shift;
    $self->{owner_name} = shift;
    $self->{service_name} = shift;
    $self->{objects} = {};

    bless $self, $class;

    return $self;
}


=item my $bus = $service->get_bus;

Retrieves a handle for the bus to which this service is attached.
The returned object will be an instance of L<Net::DBus>.

=cut

sub get_bus {
    my $self = shift;

    return $self->{bus};
}


=item my $service_name = $service->get_service_name

Retrieves the name of the remote service as known to the bus.

=cut

sub get_service_name {
    my $self = shift;
    return $self->{service_name};
}

=item my $owner_name = $service->get_owner_name;

Retrieves the name of the client owning the service at the
time it was connected to.

=cut

sub get_owner_name {
    my $self = shift;
    return $self->{owner_name};
}

=item my $object = $service->get_object($object_path[, $interface]);
=item my $object = $service->get_object($object_path, \%params);

Retrieves a handle to the remote object provided by the service  with
the name of C<$object_path>. If the optional C<$interface> parameter is
provided, the object will immediately be cast to the designated
interface. NB, it is only necessary to cast an object to a specific
interface if there are multiple interfaces on the object providing
methods with the same name, or the remote object does support
introspection. The returned object will be an instance of L<Net::DBus::RemoteObject>.

An alternate form of the method is available, passing a hash reference
of extra parameters. Valid keys in the hash are C<interface> specifying
the interface name to cast to, and C<timeout> specifying a timeout in
milliseconds

=cut

sub get_object {
    my $self = shift;
    my $object_path = shift;

    my $timeout;
    my $interface;

    if (@_) {
	if (int(@_) == 1) {
	    $interface = shift;
	} else {
	    my %params = @_;
	    $interface = $params{interface};
	    $timeout = $params{timeout};
	}
    }

    unless (defined $self->{objects}->{$object_path}) {
	$self->{objects}->{$object_path} = Net::DBus::RemoteObject->new($self,
									$object_path,
									undef,
									timeout => $timeout);
    }

    if (defined $interface) {
	return $self->{objects}->{$object_path}->as_interface($interface);
    } else {
	return $self->{objects}->{$object_path};
    }
}

=item my $timeout = $service->timeout(60 * 1000);

Sets or retrieves the timeout value which will be used for DBus
requests belongs to this service. The value is in milliseconds.
If the timeout for a service is undefined, then the default
timeout from the bus will apply.

=cut

sub timeout {
    my $self = shift;
    if (@_) {
        $self->{timeout} = shift;
    }
    return $self->{timeout};
}

1;


=pod

=back

=head1 AUTHOR

Daniel Berrange <dan@berrange.com>

=head1 COPYRIGHT

Copright (C) 2004-2011, Daniel Berrange.

=head1 SEE ALSO

L<Net::DBus::RemoteObject>, L<Net::DBus::Service>, L<Net::DBus>

=cut
