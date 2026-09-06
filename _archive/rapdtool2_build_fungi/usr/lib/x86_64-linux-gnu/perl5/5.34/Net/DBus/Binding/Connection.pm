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

Net::DBus::Binding::Connection - A connection between client and server

=head1 SYNOPSIS

Creating a connection to a server and sending a message

  use Net::DBus::Binding::Connection;

  my $con = Net::DBus::Binding::Connection->new(address => "unix:path=/path/to/socket");

  $con->send($message);

Registering message handlers

  sub handle_something {
      my $con = shift;
      my $msg = shift;

      ... do something with the message...
  }

  $con->register_message_handler(
    "/some/object/path",
    \&handle_something);

Hooking up to an event loop:

  my $reactor = Net::DBus::Binding::Reactor->new();

  $reactor->manage($con);

  $reactor->run();

=head1 DESCRIPTION

An outgoing connection to a server, or an incoming connection
from a client. The methods defined on this module have a close
correspondence to the dbus_connection_XXX methods in the C API,
so for further details on their behaviour, the C API documentation
may be of use.

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Connection;

use 5.006;
use strict;
use warnings;

use Net::DBus;
use Net::DBus::Binding::Message::MethodCall;
use Net::DBus::Binding::Message::MethodReturn;
use Net::DBus::Binding::Message::Error;
use Net::DBus::Binding::Message::Signal;
use Net::DBus::Binding::PendingCall;

=item my $con = Net::DBus::Binding::Connection->new(address => "unix:path=/path/to/socket");

Creates a new connection to the remove server specified by
the parameter C<address>. If the C<private> parameter is
supplied, and set to a True value the connection opened is
private; otherwise a shared connection is opened. A private
connection must be explicitly shutdown with the C<disconnect>
method before the last reference to the object is released.
A shared connection must never be explicitly disconnected.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    my $private = $params{private} ? $params{private} : 0;
    $self->{address} = exists $params{address} ? $params{address} : (exists $params{connection} ? "" : die "address parameter is required");
    $self->{connection} = exists $params{connection} ? $params{connection} :
	($private ?
	 Net::DBus::Binding::Connection::_open_private($self->{address}) :
	 Net::DBus::Binding::Connection::_open($self->{address}));

    bless $self, $class;

    $self->{connection}->_set_owner($self);

    return $self;
}


=item $status = $con->is_connected();

Returns zero if the connection has been disconnected,
otherwise a positive value is returned.

=cut

sub is_connected {
    my $self = shift;

    return $self->{connection}->dbus_connection_get_is_connected();
}

=item $status = $con->is_authenticated();

Returns zero if the connection has not yet successfully
completed authentication, otherwise a positive value is
returned.

=cut

sub is_authenticated {
    my $self = shift;

    return $self->{connection}->dbus_connection_get_is_authenticated();
}


=item $con->disconnect()

Closes this connection to the remote host. This method
is called automatically during garbage collection (ie
in the DESTROY method) if the programmer forgets to
explicitly disconnect.

=cut

sub disconnect {
    my $self = shift;

    $self->{connection}->dbus_connection_disconnect();
}

=item $con->flush()

Blocks execution until all data in the outgoing data
stream has been sent. This method will not re-enter
the application event loop.

=cut

sub flush {
    my $self = shift;

    $self->{connection}->dbus_connection_flush();
}


=item $con->send($message)

Queues a message up for sending to the remote host.
The data will be sent asynchronously as the applications
event loop determines there is space in the outgoing
socket send buffer. To force immediate sending of the
data, follow this method will a call to C<flush>. This
method will return the serial number of the message,
which can be used to identify a subsequent reply (if
any).

=cut

sub send {
    my $self = shift;
    my $msg = shift;

    return $self->{connection}->_send($msg->{message});
}

=item my $reply = $con->send_with_reply_and_block($msg, $timeout);

Queues a message up for sending to the remote host
and blocks until it has been sent, and a corresponding
reply received. The return value of this method will
be a C<Net::DBus::Binding::Message::MethodReturn> or C<Net::DBus::Binding::Message::Error>
object.

=cut

sub send_with_reply_and_block {
    my $self = shift;
    my $msg = shift;
    my $timeout = shift;

    my $reply = $self->{connection}->_send_with_reply_and_block($msg->{message}, $timeout);

    my $type = $reply->dbus_message_get_type;
    if ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_ERROR) {
	return $self->make_raw_message($reply);
    } elsif ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_RETURN) {
	return $self->make_raw_message($reply);
    } else {
	die "unknown method reply type $type";
    }
}


=item my $pending_call = $con->send_with_reply($msg, $timeout);

Queues a message up for sending to the remote host
and returns immediately providing a reference to a
C<Net::DBus::Binding::PendingCall> object. This object
can be used to wait / watch for a reply. This allows
methods to be processed asynchronously.

=cut

sub send_with_reply {
    my $self = shift;
    my $msg = shift;
    my $timeout = shift;

    my $reply = $self->{connection}->_send_with_reply($msg->{message}, $timeout);

    return Net::DBus::Binding::PendingCall->new(connection => $self,
						method_call => $msg,
						pending_call => $reply);
}


=item $con->dispatch;

Dispatches any pending messages in the incoming queue
to their message handlers. This method is typically
called on each iteration of the main application event
loop where data has been read from the incoming socket.

=cut

sub dispatch {
    my $self = shift;

    $self->{connection}->_dispatch();
}


=item $message = $con->borrow_message

Temporarily removes the first message from the incoming
message queue. No other thread may access the message
while it is 'borrowed', so it should be replaced in the
queue with the C<return_message> method, or removed
permanently with th C<steal_message> method as soon as
is practical.

=cut

sub borrow_message {
    my $self = shift;

    my $msg = $self->{connection}->dbus_connection_borrow_message();
    return $self->make_raw_message($msg);
}

=item $con->return_message($msg)

Replaces a previously borrowed message in the incoming
message queue for subsequent dispatch to registered
message handlers.

=cut

sub return_message {
    my $self = shift;
    my $msg = shift;

    $self->{connection}->dbus_connection_return_message($msg->{message});
}


=item $con->steal_message($msg)

Permanently remove a borrowed message from the incoming
message queue. No registered message handlers will now
be run for this message.

=cut

sub steal_message {
    my $self = shift;
    my $msg = shift;

    $self->{connection}->dbus_connection_steal_borrowed_message($msg->{message});
}

=item $msg = $con->pop_message();

Permanently removes the first message on the incoming
message queue, without running any registered message
handlers. If you have hooked the connection up to an
event loop (C<Net::DBus::Binding::Reactor> for example), you probably
don't want to be calling this method.

=cut

sub pop_message {
    my $self = shift;

    my $msg = $self->{connection}->dbus_connection_pop_message();
    return $self->make_raw_message($msg);
}

=item $con->set_watch_callbacks(\&add_watch, \&remove_watch, \&toggle_watch);

Register a set of callbacks for adding, removing & updating
watches in the application's event loop. Each parameter
should be a code reference, which on each invocation, will be
supplied with two parameters, the connection object and the
watch object. If you are using a C<Net::DBus::Binding::Reactor> object
as the application event loop, then the 'manage' method on
that object will call this on your behalf.

=cut

sub set_watch_callbacks {
    my $self = shift;
    my $add = shift;
    my $remove = shift;
    my $toggled = shift;

    $self->{add_watch} = $add;
    $self->{remove_watch} = $remove;
    $self->{toggled_watch} = $toggled;

    $self->{connection}->_set_watch_callbacks();
}

=item $con->set_timeout_callbacks(\&add_timeout, \&remove_timeout, \&toggle_timeout);

Register a set of callbacks for adding, removing & updating
timeouts in the application's event loop. Each parameter
should be a code reference, which on each invocation, will be
supplied with two parameters, the connection object and the
timeout object. If you are using a C<Net::DBus::Binding::Reactor> object
as the application event loop, then the 'manage' method on
that object will call this on your behalf.

=cut

sub set_timeout_callbacks {
    my $self = shift;
    my $add = shift;
    my $remove = shift;
    my $toggled = shift;

    $self->{add_timeout} = $add;
    $self->{remove_timeout} = $remove;
    $self->{toggled_timeout} = $toggled;

    $self->{connection}->_set_timeout_callbacks();
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

    my $callback = sub {
	my $con = shift;
	my $msg = shift;

	&$code($con, $self->make_raw_message($msg));
    };
    $self->{connection}->_register_object_path($path, $callback);
}

=item $con->unregister_object_path($path)

Unregisters the handler associated with the object path C<$path>. The
handler would previously have been registered with the C<register_object_path>
or C<register_fallback> methods.

=cut

sub unregister_object_path {
    my $self = shift;
    my $path = shift;
    $self->{connection}->_unregister_object_path($path);
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

    my $callback = sub {
	my $con = shift;
	my $msg = shift;

	&$code($con, $self->make_raw_message($msg));
    };

    $self->{connection}->_register_fallback($path, $callback);
}


=item $con->set_max_message_size($bytes)

Sets the maximum allowable size of a single incoming
message. Messages over this size will be rejected
prior to exceeding this threshold. The message size
is specified in bytes.

=cut

sub set_max_message_size {
    my $self = shift;
    my $size = shift;

    $self->{connection}->dbus_connection_set_max_message_size($size);
}

=item $bytes = $con->get_max_message_size();

Retrieves the maximum allowable incoming
message size. The returned size is measured
in bytes.

=cut

sub get_max_message_size {
    my $self = shift;

    return $self->{connection}->dbus_connection_get_max_message_size;
}

=item $con->set_max_received_size($bytes)

Sets the maximum size of the incoming message queue.
Once this threshold is exceeded, no more messages will
be read from wire before one or more of the existing
messages are dispatched to their registered handlers.
The implication is that the message queue can exceed
this threshold by at most the size of a single message.

=cut

sub set_max_received_size {
    my $self = shift;
    my $size = shift;

    $self->{connection}->dbus_connection_set_max_received_size($size);
}

=item $bytes $con->get_max_received_size()

Retrieves the maximum incoming message queue size.
The returned size is measured in bytes.

=cut

sub get_max_received_size {
    my $self = shift;

    return $self->{connection}->dbus_connection_get_max_received_size;
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
    my $callback = shift;

    $self->{connection}->_add_filter($callback);
}


sub _message_filter {
    my $self = shift;
    my $rawmsg = shift;
    my $code = shift;

    my $msg = $self->make_raw_message($rawmsg);
    return &$code($self, $msg);
}


=item my $msg = $con->make_raw_message($rawmsg)

Creates a new message, initializing it from the low level C message
object provided by the C<$rawmsg> parameter. The returned object
will be cast to the appropriate subclass of L<Net::DBus::Binding::Message>.

=cut

sub make_raw_message {
    my $self = shift;
    my $rawmsg = shift;

    return Net::DBus::Binding::Message->new(message => $rawmsg);
}


=item my $msg = $con->make_error_message(
      replyto => $method_call, name => $name, description => $description);

Creates a new message, representing an error which occurred during
the handling of the method call object passed in as the C<replyto>
parameter. The C<name> parameter is the formal name of the error
condition, while the C<description> is a short piece of text giving
more specific information on the error.

=cut


sub make_error_message {
    my $self = shift;
    my $replyto = shift;
    my $name = shift;
    my $description = shift;

    return Net::DBus::Binding::Message::Error->new(replyto => $replyto,
						   name => $name,
						   description => $description);
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

    return Net::DBus::Binding::Message::MethodCall->new(service_name => $service_name,
							object_path => $object_path,
							interface => $interface,
							method_name => $method_name);
}

=item my $msg = $con->make_method_return_message(
    replyto => $method_call);

Create a message representing a reply to the method call passed in
the C<replyto> parameter.

=cut


sub make_method_return_message {
    my $self = shift;
    my $replyto = shift;

    return Net::DBus::Binding::Message::MethodReturn->new(call => $replyto);
}


=item my $signal = $con->make_signal_message(
      object_path => $path, interface => $interface, signal_name => $name);

Creates a new message, representing a signal [to be] emitted by
the object located under the path given by the C<object_path>
parameter. The name of the signal is given by the C<signal_name>
parameter, and is scoped to the interface given by the
C<interface> parameter.

=cut

sub make_signal_message {
    my $self = shift;
    my $object_path = shift;
    my $interface = shift;
    my $signal_name = shift;

    return Net::DBus::Binding::Message::Signal->new(object_path => $object_path,
						    interface => $interface,
						    signal_name => $signal_name);
}

1;

=pod

=back

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2004-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Binding::Server>, L<Net::DBus::Binding::Bus>, L<Net::DBus::Binding::Message::Signal>, L<Net::DBus::Binding::Message::MethodCall>, L<Net::DBus::Binding::Message::MethodReturn>, L<Net::DBus::Binding::Message::Error>

=cut
