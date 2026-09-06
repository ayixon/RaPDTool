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

Net::DBus::Binding::Value - Strongly typed data value

=head1 SYNOPSIS

  # Import the convenience functions
  use Net::DBus qw(:typing);

  # Call a method with passing an int32
  $object->doit(dint32("3"));

=head1 DESCRIPTION

This module provides a simple wrapper around a raw Perl value,
associating an explicit DBus type with the value. This is used
in cases where a client is communicating with a server which does
not provide introspection data, but for which the basic data types
are not sufficient. This class should not be used directly, rather
the convenience functions in L<Net::DBus> be called.

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Value;

use strict;
use warnings;

=item my $value = Net::DBus::Binding::Value->new($type, $value);

Creates a wrapper for the perl value C<$value> marking it as having
the dbus data type C<$type>. It is not necessary to call this method
directly, instead the data typing methods in the L<Net::DBus> object
should be used.

=cut

sub new {
    my $class = shift;
    my $self = [];

    $self->[0] = shift;
    $self->[1] = shift;

    bless $self, $class;

    return $self;
}

=item my $raw = $value->value

Returns the raw perl value wrapped by this object

=cut

sub value {
    my $self = shift;
    return $self->[1];
}

=item my $type = $value->type

Returns the dbus data type this value is marked
as having

=cut

sub type {
    my $self = shift;
    return $self->[0];
}

1;

=pod

=back

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2004-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Binding::Introspector>, L<Net::DBus::Binding::Iterator>

=cut
