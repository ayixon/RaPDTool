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

Net::DBus::Binding::Message::Signal - a message encoding a signal

=head1 SYNOPSIS

  use Net::DBus::Binding::Message::Signal;

  my $signal = Net::DBus::Binding::Message::Signal->new(
      object_path => "/org/example/myobject",
      interface => "org.example.myobject",
      signal_name => "foo_changed");

  $connection->send($signal);

=head1 DESCRIPTION

This module is part of the low-level DBus binding APIs, and
should not be used by application code. No guarantees are made
about APIs under the C<Net::DBus::Binding::> namespace being
stable across releases.

This module provides a convenience constructor for creating
a message representing a signal.

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Message::Signal;

use 5.006;
use strict;
use warnings;

use Net::DBus;
use base qw(Net::DBus::Binding::Message);


=item my $signal = Net::DBus::Binding::Message::Signal->new(
      object_path => $path, interface => $interface, signal_name => $name);

Creates a new message, representing a signal [to be] emitted by
the object located under the path given by the C<object_path>
parameter. The name of the signal is given by the C<signal_name>
parameter, and is scoped to the interface given by the
C<interface> parameter.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $msg = exists $params{message} ? $params{message} :
	Net::DBus::Binding::Message::Signal::_create
	(
	 ($params{object_path} ? $params{object_path} : die "object_path parameter is required"),
	 ($params{interface} ? $params{interface} : die "interface parameter is required"),
	 ($params{signal_name} ? $params{signal_name} : die "signal_name parameter is required"));

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
