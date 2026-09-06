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

Net::DBus::Binding::Message::MethodCall - a message encoding a method call

=head1 DESCRIPTION

This module is part of the low-level DBus binding APIs, and
should not be used by application code. No guarantees are made
about APIs under the C<Net::DBus::Binding::> namespace being
stable across releases.

This module provides a convenience constructor for creating
a message representing a method call.

=head1 METHODS

=over 4

=cut


package Net::DBus::Binding::Message::MethodCall;

use 5.006;
use strict;
use warnings;

use Net::DBus;
use base qw(Exporter Net::DBus::Binding::Message);

=item my $call = Net::DBus::Binding::Message::MethodCall->new(
  service_name => $service, object_path => $object,
  interface => $interface, method_name => $name);

Create a message representing a call on the object located at
the path C<object_path> within the client owning the well-known
name given by C<service_name>. The method to be invoked has
the name C<method_name> within the interface specified by the
C<interface> parameter.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $msg = exists $params{message} ? $params{message} :
	Net::DBus::Binding::Message::MethodCall::_create
	(
	 ($params{service_name} ? $params{service_name} : die "service_name parameter is required"),
	 ($params{object_path} ? $params{object_path} : die "object_path parameter is required"),
	 ($params{interface} ? $params{interface} : die "interface parameter is required"),
	 ($params{method_name} ? $params{method_name} : die "method_name parameter is required"));

    my $self = $class->SUPER::new(message => $msg);

    bless $self, $class;

    return $self;
}

1;

__END__

=back

=head1 AUTHOR

Daniel P. Berrange.

=head1 COPYRIGHT

Copyright (C) 2004-2009 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Binding::Message>

=cut
