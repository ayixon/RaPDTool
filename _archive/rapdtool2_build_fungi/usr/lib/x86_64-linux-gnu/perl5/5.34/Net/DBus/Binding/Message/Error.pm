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

Net::DBus::Binding::Message::Error - a message encoding a method call error

=head1 SYNOPSIS

  use Net::DBus::Binding::Message::Error;

  my $error = Net::DBus::Binding::Message::Error->new(
      replyto => $method_call,
      name => "org.example.myobject.FooException",
      description => "Unable to do Foo when updating bar");

  $connection->send($error);

=head1 DESCRIPTION

This module is part of the low-level DBus binding APIs, and
should not be used by application code. No guarantees are made
about APIs under the C<Net::DBus::Binding::> namespace being
stable across releases.

This module provides a convenience constructor for creating
a message representing an error condition.

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Message::Error;

use 5.006;
use strict;
use warnings;

use Net::DBus;
use base qw(Net::DBus::Binding::Message);

=item my $error = Net::DBus::Binding::Message::Error->new(
      replyto => $method_call, name => $name, description => $description);

Creates a new message, representing an error which occurred during
the handling of the method call object passed in as the C<replyto>
parameter. The C<name> parameter is the formal name of the error
condition, while the C<description> is a short piece of text giving
more specific information on the error.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $replyto = exists $params{replyto} ? $params{replyto} : die "replyto parameter is required";

    my $msg = exists $params{message} ? $params{message} :
	Net::DBus::Binding::Message::Error::_create
	(
	 $replyto->{message},
	 ($params{name} ? $params{name} : die "name parameter is required"),
	 ($params{description} ? $params{description} : die "description parameter is required"));

    my $self = $class->SUPER::new(message => $msg);

    bless $self, $class;

    return $self;
}

=item my $name = $error->get_error_name

Returns the formal name of the error, as previously passed in via
the C<name> parameter in the constructor.

=cut

sub get_error_name {
    my $self = shift;

    return $self->{message}->dbus_message_get_error_name;
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
