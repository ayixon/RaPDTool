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

Net::DBus::Test::MockConnection - Fake a connection to the bus unit testing

=head1 SYNOPSIS

  use Net::DBus;

  my $bus = Net::DBus->test

  # Register a service, and the objec to be tested
  use MyObject
  my $service = $bus->export_service("org.example.MyService");
  my $object = MyObject->new($service);


  # Acquire the service & do tests
  my $remote_service = $bus->get_service('org.example.MyService');
  my $remote_object = $service->get_object("/org/example/MyObjct");

  # This traverses the mock connection, eventually
  # invoking 'testSomething' on the $object above.
  $remote_object->testSomething()

=head1 DESCRIPTION

This object provides a fake implementation of the L<Net::DBus::Binding::Connection>
enabling a pure 'in-memory' message bus to be mocked up. This is intended to
facilitate creation of unit tests for services which would otherwise need to
call out to other object on a live message bus. It is used as a companion to
the L<Net::DBus::Test::MockObject> module which is how fake objects are to be
provided on the fake bus.

=head1 METHODS

=over 4

=cut

package Net::DBus::Test::MockConnection;

use strict;
use warnings;

use Net::DBus::Error;
use Net::DBus::Test::MockMessage;
use Net::DBus::Binding::Message::MethodCall;
use Net::DBus::Binding::Message::MethodReturn;
use Net::DBus::Binding::Message::Error;
use Net::DBus::Binding::Message::Signal;

=item my $con = Net::DBus::Test::MockConnection->new()

Create a new mock connection object instance. It is not usually
necessary to create instances of this object directly, instead
the C<test> method on the L<Net::DBus> object can be used to
get a handle to a test bus.

=cut

sub new {
    my $class = shift;
    my $self = {};

    $self->{replies} = [];
    $self->{signals} = [];
    $self->{objects} = {};
    $self->{objectTrees} = {};
    $self->{filters} = [];

    bless $self, $class;

    return $self;
}

=item $con->send($message)

Send a message over the mock connection. If the message is
a method call, it will be dispatched straight to any corresponding
mock object registered. If the message is an error or method return
it will be made available as a return value for the C<send_with_reply_and_block>
method. If the message is a signal it will be queued up for processing
by the C<dispatch> method.

=cut


sub send {
    my $self = shift;
    my $msg = shift;

    if ($msg->get_type() == &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_CALL) {
	$self->_call_method($msg);
    } elsif ($msg->get_type() == &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_RETURN ||
	     $msg->get_type() == &Net::DBus::Binding::Message::MESSAGE_TYPE_ERROR) {
	push @{$self->{replies}}, $msg;
    } elsif ($msg->get_type() == &Net::DBus::Binding::Message::MESSAGE_TYPE_SIGNAL) {
	push @{$self->{signals}}, $msg;
    } else {
	die "unhandled type of message " . ref($msg);
    }
}


=item $bus->request_name($service_name)

Pretend to send a request to the bus registering the well known
name specified in the C<$service_name> parameter. In reality
this is just a no-op giving the impression that the name was
successfully registered.

=cut

sub request_name {
    my $self = shift;
    my $name = shift;
    my $flags = shift;

    # XXX do we care about this for test cases? probably not...
    # ....famous last words
}

=item my $reply = $con->send_with_reply_and_block($msg)

Send a message over the mock connection and wait for a
reply. The C<$msg> should be an instance of C<Net::DBus::Binding::Message::MethodCall>
and the return C<$reply> will be an instance of C<Net::DBus::Binding::Message::MethodReturn>.
It is also possible that an error will be thrown, with
the thrown error being blessed into the C<Net::DBus::Error>
class.

=cut

sub send_with_reply_and_block {
    my $self = shift;
    my $msg = shift;
    my $timeout = shift;

    $self->send($msg);

    if ($#{$self->{replies}} == -1) {
	die "no reply for " . $msg->get_path . "->" . $msg->get_member . " received within timeout";
    }

    my $reply = shift @{$self->{replies}};
    if ($#{$self->{replies}} != -1) {
	die "too many replies received";
    }

    if ($reply->get_type() == &Net::DBus::Binding::Message::MESSAGE_TYPE_ERROR) {
	my $iter = $reply->iterator;
	my $desc = $iter->get_string;
	die Net::DBus::Error->new(name => $reply->get_error_name,
				  message => $desc);
    }

    return $reply;
}

=item $con->dispatch;

Dispatches any pending messages in the incoming queue
to their message handlers. This method should be called
by test suites whenever they anticipate that there are
pending signals to be dealt with.

=cut

sub dispatch {
    my $self = shift;

    my @signals = @{$self->{signals}};
    $self->{signals} = [];
    foreach my $msg (@signals) {
	foreach my $cb (@{$self->{filters}}) {
	    # XXX we should worry about return value...
	    &$cb($self, $msg);
	}
    }
}

=item $con->add_filter($coderef);

Adds a filter to the connection which will be invoked whenever a
message is received. The C<$coderef> should be a reference to a
subroutine, which returns a true value if the message should be
filtered out, or a false value if the normal message dispatch
should be performed.

=cut

sub add_filter {
    my $self = shift;
    my $cb = shift;

    push @{$self->{filters}}, $cb;
}

=item $bus->add_match($rule)

Register a signal match rule with the bus controller, allowing
matching broadcast signals to routed to this client. In reality
this is just a no-op giving the impression that the match was
successfully registered.

=cut

sub add_match {
    my $self = shift;
    my $rule = shift;

    # XXX do we need to implement anything ? probably not
    # nada
}

=item $bus->remove_match($rule)

Unregister a signal match rule with the bus controller, preventing
further broadcast signals being routed to this client. In reality
this is just a no-op giving the impression that the match was
successfully unregistered.

=cut

sub remove_match {
    my $self = shift;
    my $rule = shift;

    # XXX do we need to implement anything ? probably not
    # nada
}


=item $con->register_object_path($path, \&handler)

Registers a handler for messages whose path matches
that specified in the C<$path> parameter. The supplied
code reference will be invoked with two parameters, the
connection object on which the message was received,
and the message to be processed (an instance of the
C<Net::DBus::Binding::Message> class).

=cut

sub register_object_path {
    my $self = shift;
    my $path = shift;
    my $code = shift;

    $self->{objects}->{$path} = $code;
}

=item $con->register_fallback($path, \&handler)

Registers a handler for messages whose path starts with
the prefix specified in the C<$path> parameter. The supplied
code reference will be invoked with two parameters, the
connection object on which the message was received,
and the message to be processed (an instance of the
C<Net::DBus::Binding::Message> class).

=cut

sub register_fallback {
    my $self = shift;
    my $path = shift;
    my $code = shift;

    $self->{objects}->{$path} = $code;
    $self->{objectTrees}->{$path} = $code;
}

=item $con->unregister_object_path($path)

Unregisters the handler associated with the object path C<$path>. The
handler would previously have been registered with the C<register_object_path>
or C<register_fallback> methods.

=cut

sub unregister_object_path {
    my $self = shift;
    my $path = shift;

    delete $self->{objects}->{$path};
}

sub _call_method {
    my $self = shift;
    my $msg = shift;

    if (exists $self->{objects}->{$msg->get_path}) {
	my $cb = $self->{objects}->{$msg->get_path};
	&$cb($self, $msg);
    } else {
	foreach my $path (reverse sort { $a cmp $b } keys %{$self->{objectTrees}}) {
	    if ((index $msg->get_path, $path) == 0) {
		my $cb = $self->{objects}->{$path};
		&$cb($self, $msg);
		return;
	    }
	}
	if ($msg->get_path eq "/org/freedesktop/DBus") {
	    if ($msg->get_member eq "GetNameOwner") {
		my $reply = $self->make_method_return_message($msg);
		my $iter = $reply->iterator(1);
		$iter->append(":1.1");
		$self->send($reply);
	    }
	}
    }
}

=item my $msg = $con->make_error_message($replyto, $name, $description)

Creates a new message, representing an error which occurred during
the handling of the method call object passed in as the C<$replyto>
parameter. The C<$name> parameter is the formal name of the error
condition, while the C<$description> is a short piece of text giving
more specific information on the error.

=cut

sub make_error_message {
    my $self = shift;
    my $replyto = shift;
    my $name = shift;
    my $description = shift;

    if (1) {
	return Net::DBus::Test::MockMessage->new_error(replyto => $replyto,
						       error_name => $name,
						       error_description => $description);
    } else {
	return Net::DBus::Binding::Message::Error->new(replyto => $replyto,
						       name => $name,
						       description => $description);
    }
}

=item my $call = $con->make_method_call_message(
  $service_name, $object_path, $interface, $method_name);

Create a message representing a call on the object located at
the path C<$object_path> within the client owning the well-known
name given by C<$service_name>. The method to be invoked has
the name C<$method_name> within the interface specified by the
C<$interface> parameter.

=cut

sub make_method_call_message {
    my $self = shift;
    my $service_name = shift;
    my $object_path = shift;
    my $interface = shift;
    my $method_name = shift;

    if (1) {
	return Net::DBus::Test::MockMessage->new_method_call(destination => $service_name,
							     path => $object_path,
							     interface => $interface,
							     member => $method_name);
    } else {
	return Net::DBus::Binding::Message::MethodCall->new(service_name => $service_name,
							    object_path => $object_path,
							    interface => $interface,
							    method_name => $method_name);
    }
}

=item my $msg = $con->make_method_return_message($replyto)

Create a message representing a reply to the method call message passed in
the C<$replyto> parameter.

=cut


sub make_method_return_message {
    my $self = shift;
    my $replyto = shift;

    if (1) {
	return Net::DBus::Test::MockMessage->new_method_return(replyto => $replyto);
    } else {
	return Net::DBus::Binding::Message::MethodReturn->new(call => $replyto);
    }
}


=item my $msg = $con->make_signal_message($object_path, $interface, $signal_name);

Creates a new message, representing a signal [to be] emitted by
the object located under the path given by the C<$object_path>
parameter. The name of the signal is given by the C<$signal_name>
parameter, and is scoped to the interface given by the
C<$interface> parameter.

=cut

sub make_signal_message {
    my $self = shift;
    my $object_path = shift;
    my $interface = shift;
    my $signal_name = shift;

    if (1) {
	return Net::DBus::Test::MockMessage->new_signal(object_path => $object_path,
							interface => $interface,
							signal_name => $signal_name);
    } else {
	return Net::DBus::Binding::Message::Signal->new(object_path => $object_path,
							interface => $interface,
							signal_name => $signal_name);
    }
}


1;

=pod

=back

=head1 BUGS

It doesn't completely replicate the API of L<Net::DBus::Binding::Connection>,
merely enough to make the high level bindings work in a test scenario.

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2005-2009 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Test::MockObject>, L<Net::DBus::Binding::Connection>,
L<http://www.mockobjects.com/Faq.html>

=cut
