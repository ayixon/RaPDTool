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

Net::DBus::Callback - a callback for receiving reactor events

=head1 SYNOPSIS

  use Net::DBus::Callback;

  # Assume we have a 'terminal' object and its got a method
  # to be invoked every time there is input on its terminal.
  #
  # To create a callback to invoke this method one might use
  my $cb = Net::DBus::Callback->new(object => $terminal,
                                    method => "handle_stdio");


  # Whatever is monitoring the stdio channel, would then
  # invoke the callback, perhaps passing in a parameter with
  # some 'interesting' data, such as number of bytes available
  $cb->invoke($nbytes)

  #... which results in a call to
  #  $terminal->handle_stdio($nbytes)

=head1 DESCRIPTION

This module provides a simple container for storing details
about a callback to be invoked at a later date. It is used
when registering to receive events from the L<Net::DBus::Reactor>
class. NB use of this module in application code is no longer
necessary and it remains purely for backwards compatibility.
Instead you can simply pass a subroutine code reference in
any place where a callback is desired.

=head1 METHODS

=over 4

=cut

package Net::DBus::Callback;

use 5.006;
use strict;
use warnings;

=item my $cb = Net::DBus::Callback->new(method => $name, [args => \@args])

Creates a new callback object, for invoking a plain old function. The C<method>
parameter should be the fully qualified function name to invoke, including the
package name. The optional C<args> parameter is an array reference of parameters
to be pass to the callback, in addition to those passed into the C<invoke> method.

=item my $cb = Net::DBus::Callback->new(object => $object, method => $name, [args => \@args])

Creates a new callback object, for invoking a method on an object. The C<method>
parameter should be the name of the method to invoke, while the C<object> parameter
should be a blessed object on which the method will be invoked. The optional C<args>
parameter is an array reference of parameters to be pass to the callback, in addition
to those passed into the C<invoke> method.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    $self->{object} = $params{object} ? $params{object} : undef;
    $self->{method} = $params{method} ? $params{method} : die "method parameter is required";
    $self->{args} = $params{args} ? $params{args} : [];

    bless $self, $class;

    return $self;
}

=item $cb->invoke(@args)

Invokes the callback. The argument list passed to the callback
is a combination of the arguments supplied in the callback
constructor, followed by the arguments supplied in the C<invoke>
method.

=cut

sub invoke {
    my $self = shift;

    if ($self->{object}) {
	my $obj = $self->{object};
	my $method = $self->{method};

	$obj->$method(@{$self->{args}}, @_);
    } else {
	my $method = $self->{method};

	&$method(@{$self->{args}}, @_);
    }
}

1;

__END__

=back

=head1 AUTHOR

Daniel P. Berrange.

=head1 COPYRIGHT

Copyright (C) 2004-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Reactor>

=cut

