# -*- perl -*-
#
# Copyright (C) 2006-2011 Daniel P. Berrange
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

Net::DBus::ASyncReply - asynchronous method reply handler

=head1 SYNOPSIS

  use Net::DBus::Annotation qw(:call);

  my $object = $service->get_object("/org/example/systemMonitor");

  # List processes & get on with other work until
  # the list is returned.
  my $asyncreply = $object->list_processes(dbus_call_async, "someuser");

  while (!$asyncreply->is_ready) {
    ... do some background work..
  }

  my $processes = $asyncreply->get_result;


=head1 DESCRIPTION

This object provides a handler for receiving asynchronous
method replies. An asynchronous reply object is generated
when making remote method call with the C<dbus_call_async>
annotation set.

=head1 METHODS

=over 4

=cut

package Net::DBus::ASyncReply;

use strict;
use warnings;


sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{pending_call} = $params{pending_call} ? $params{pending_call} : die "pending_call parameter is required";
    $self->{introspector} = $params{introspector} ? $params{introspector} : undef;
    $self->{method_name} = $params{method_name} ? $params{method_name} : ($self->{introspector} ? die "method_name is parameter required for introspection" : undef);

    bless $self, $class;

    return $self;
}


=item $asyncreply->discard_result;

Indicates that the caller is no longer interested in
receiving the reply & that it should be discarded. After
calling this method, this object should not be used again.

=cut

sub discard_result {
    my $self = shift;
    my $pending_call = delete $self->{pending_call};

    $pending_call->cancel;
}


=item $asyncreply->wait_for_result;

Blocks the caller waiting for completion of the of the
asynchronous reply. Upon returning from this method, the
result can be obtained with the C<get_result> method.

=cut

sub wait_for_result {
    my $self = shift;

    $self->{pending_call}->block;
}

=item my $boolean = $asyncreply->is_ready;

Returns a true value if the asynchronous reply is now
complete (or a timeout has occurred). When this method
returns true, the result can be obtained with the C<get_result>
method.

=cut

sub is_ready {
    my $self = shift;

    return $self->{pending_call}->get_completed;
}


=item $asyncreply->set_notify($coderef);

Sets a notify function which will be invoked when the
asynchronous reply finally completes. The callback will
be invoked with a single parameter which is this object.

=cut

sub set_notify {
    my $self = shift;
    my $cb = shift;

    $self->{pending_call}->set_notify(sub {
	my $pending_call = shift;

	&$cb($self);
    });
}

=item my @data = $asyncreply->get_result;

Retrieves the data associated with the asynchronous reply.
If a timeout occurred, then this method will throw an
exception. This method can only be called once the reply
is complete, as indicated by the C<is_ready> method
returning a true value. After calling this method, this
object should no longer be used.

=cut

sub get_result {
    my $self = shift;
    my $pending_call = delete $self->{pending_call};

    my $reply = $pending_call->get_reply;

    if ($reply->isa("Net::DBus::Binding::Message::Error")) {
	my $iter = $reply->iterator();
	my $desc = $iter->get_string();
	die Net::DBus::Error->new(name => $reply->get_error_name,
				  message => $desc);
    }

    my @reply;
    if ($self->{introspector}) {
	@reply = $self->{introspector}->decode($reply, "methods", $self->{method_name}, "returns");
    } else {
	@reply = $reply->get_args_list;
    }

    return wantarray ? @reply : $reply[0];
}

1;

=pod

=back

=head1 AUTHOR

Daniel Berrange <dan@berrange.com>

=head1 COPYRIGHT

Copright (C) 2006-2011, Daniel Berrange.

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::RemoteObject>, L<Net::DBus::Annotation>

=cut
