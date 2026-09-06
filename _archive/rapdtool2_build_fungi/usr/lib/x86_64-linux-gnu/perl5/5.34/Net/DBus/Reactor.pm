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

Net::DBus::Reactor - application event loop

=head1 SYNOPSIS

Create and run an event loop:

   use Net::DBus::Reactor;
   my $reactor = Net::DBus::Reactor->main();

   $reactor->run();

Manage some file handlers

   $reactor->add_read($fd,
                      Net::DBus::Callback->new(method => sub {
                         my $fd = shift;
                         ...read some data...
                      }, args => [$fd]));

   $reactor->add_write($fd,
                       Net::DBus::Callback->new(method => sub {
                          my $fd = shift;
                          ...write some data...
                       }, args => [$fd]));

Temporarily (dis|en)able a handle

   # Disable
   $reactor->toggle_read($fd, 0);
   # Enable
   $reactor->toggle_read($fd, 1);

Permanently remove a handle

   $reactor->remove_read($fd);

Manage a regular timeout every 100 milliseconds

   my $timer = $reactor->add_timeout(100,
                                     Net::DBus::Callback->new(
              method => sub {
                 ...process the alarm...
              }));

Temporarily (dis|en)able a timer

   # Disable
   $reactor->toggle_timeout($timer, 0);
   # Enable
   $reactor->toggle_timeout($timer, 1);

Permanently remove a timer

   $reactor->remove_timeout($timer);

Add a post-dispatch hook

   my $hook = $reactor->add_hook(Net::DBus::Callback->new(
         method => sub {
            ... do some work...
         }));

Remove a hook

   $reactor->remove_hook($hook);

=head1 DESCRIPTION

This class provides a general purpose event loop for
the purposes of multiplexing I/O events and timeouts
in a single process. The underlying implementation is
done using the select system call. File handles can
be registered for monitoring on read, write and exception
(out-of-band data) events. Timers can be registered
to expire with a periodic frequency. These are implemented
using the timeout parameter of the select system call.
Since this parameter merely represents an upper bound
on the amount of time the select system call is allowed
to sleep, the actual period of the timers may vary. Under
normal load this variance is typically 10 milliseconds.
Finally, hooks may be registered which will be invoked on
each iteration of the event loop (ie after processing
the file events, or timeouts indicated by the select
system call returning).

=head1 METHODS

=over 4

=cut

package Net::DBus::Reactor;

use 5.006;
use strict;
use warnings;

use Net::DBus::Binding::Watch;
use Net::DBus::Callback;
use Time::HiRes qw(gettimeofday);

=item my $reactor = Net::DBus::Reactor->new();

Creates a new event loop ready for monitoring file handles, or
generating timeouts. Except in very unusual circumstances (examples
of which I can't think up) it is not necessary or desriable to
explicitly create new reactor instances. Instead call the L<main>
method to get a handle to the singleton instance.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    $self->{fds} = {
	read => {},
	write => {},
	exception => {}
    };
    $self->{timeouts} = [];
    $self->{hooks} = [];

    bless $self, $class;

    return $self;
}

use vars qw($main_reactor);

=item $reactor = Net::DBus::Reactor->main;

Return a handle to the singleton instance of the reactor. This
is the recommended way of getting hold of a reactor, since it
removes the need for modules to pass around handles to their
privately created reactors.

=cut

sub main {
    my $class = shift;
    $main_reactor = $class->new() unless defined $main_reactor;
    return $main_reactor;
}


=item $reactor->manage($connection);

=item $reactor->manage($server);

Registers a C<Net::DBus::Binding::Connection> or C<Net::DBus::Binding::Server> object
for management by the event loop. This basically involves
hooking up the watch & timeout callbacks to the event loop.
For connections it will also register a hook to invoke the
C<dispatch> method periodically.

=cut

sub manage {
    my $self = shift;
    my $object = shift;

    if ($object->can("set_watch_callbacks")) {
	$object->set_watch_callbacks(sub {
	    my $object = shift;
	    my $watch = shift;

	    $self->_manage_watch_on($object, $watch);
	}, sub {
	    my $object = shift;
	    my $watch = shift;

	    $self->_manage_watch_off($object, $watch);
	}, sub {
	    my $object = shift;
	    my $watch = shift;

	    $self->_manage_watch_toggle($object, $watch);
	});
    }

    if ($object->can("set_timeout_callbacks")) {
	$object->set_timeout_callbacks(sub {
	    my $object = shift;
	    my $timeout = shift;
	
	    my $key = $self->add_timeout($timeout->get_interval,
					 Net::DBus::Callback->new(object => $timeout,
								  method => "handle",
								  args => []),
					 $timeout->is_enabled);
	    $timeout->set_data($key);
	}, sub {
	    my $object = shift;
	    my $timeout = shift;
	
	    my $key = $timeout->get_data;
	    $self->remove_timeout($key);
	}, sub {
	    my $object = shift;
	    my $timeout = shift;
	
	    my $key = $timeout->get_data;
	    $self->toggle_timeout($key,
				  $timeout->is_enabled,
				  $timeout->get_interval);
	});
    }

    if ($object->can("dispatch")) {
	$self->add_hook(Net::DBus::Callback->new(object => $object,
						 method => "dispatch",
						 args => []),
			1);
    }
    if ($object->can("flush")) {
	$self->add_hook(Net::DBus::Callback->new(object => $object,
						 method => "flush",
						 args => []),
			1);
    }
}


sub _manage_watch_on {
    my $self = shift;
    my $object = shift;
    my $watch = shift;
    my $flags = $watch->get_flags;

    if ($flags & &Net::DBus::Binding::Watch::READABLE) {
	$self->add_read($watch->get_fileno,
			Net::DBus::Callback->new(object => $watch,
					    method => "handle",
					    args => [&Net::DBus::Binding::Watch::READABLE]),
			$watch->is_enabled);
    }
    if ($flags & &Net::DBus::Binding::Watch::WRITABLE) {
	$self->add_write($watch->get_fileno,
			 Net::DBus::Callback->new(object => $watch,
					     method => "handle",
					     args => [&Net::DBus::Binding::Watch::WRITABLE]),
			 $watch->is_enabled);
    }
#    $self->add_exception($watch->get_fileno, $watch,
#			 Net::DBus::Callback->new(object => $watch,
#					     method => "handle",
#					     args => [&Net::DBus::Binding::Watch::ERROR]),
#			 $watch->is_enabled);

}

sub _manage_watch_off {
    my $self = shift;
    my $object = shift;
    my $watch = shift;
    my $flags = $watch->get_flags;

    if ($flags & &Net::DBus::Binding::Watch::READABLE) {
	$self->remove_read($watch->get_fileno);
    }
    if ($flags & &Net::DBus::Binding::Watch::WRITABLE) {
	$self->remove_write($watch->get_fileno);
    }
#    $self->remove_exception($watch->get_fileno);
}

sub _manage_watch_toggle {
    my $self = shift;
    my $object = shift;
    my $watch = shift;
    my $flags = $watch->get_flags;

    if ($flags & &Net::DBus::Binding::Watch::READABLE) {
	$self->toggle_read($watch->get_fileno, $watch->is_enabled);
    }
    if ($flags & &Net::DBus::Binding::Watch::WRITABLE) {
	$self->toggle_write($watch->get_fileno, $watch->is_enabled);
    }
    $self->toggle_exception($watch->get_fileno, $watch->is_enabled);
}


=item $reactor->run();

Starts the event loop monitoring any registered
file handles and timeouts. At least one file
handle, or timer must have been registered prior
to running the reactor, otherwise it will immediately
exit. The reactor will run until all registered
file handles, or timeouts have been removed, or
disabled. The reactor can be explicitly stopped by
calling the C<shutdown> method.

=cut

sub run {
    my $self = shift;

    $self->{running} = 1;
    while ($self->{running}) { $self->step };
}

=item $reactor->shutdown();

Explicitly shutdown the reactor after pending
events have been processed.

=cut

sub shutdown {
    my $self = shift;
    $self->{running} = 0;
}

=item $reactor->step();

Perform one iteration of the event loop, going to
sleep until an event occurs on a registered file
handle, or a timeout occurrs. This method is generally
not required in day-to-day use.

=cut

sub step {
    my $self = shift;

    my @callbacks = $self->_dispatch_hook();

    foreach my $callback (@callbacks) {
	$callback->invoke;
    }

    my ($ri, $ric) = $self->_bits("read");
    my ($wi, $wic) = $self->_bits("write");
    my ($ei, $eic) = $self->_bits("exception");
    my $timeout = $self->_timeout($self->_now);

    if (!$ric && !$wic && !$eic && !(defined $timeout)) {
	$self->{running} = 0;
    }

    # One of the hooks we ran might have requested shutdown
    # so check here to avoid a undesirable wait in select()
    # cf RT #39068
    return unless $self->{running};

    my ($ro, $wo, $eo);
    my $n = select($ro=$ri,$wo=$wi,$eo=$ei, (defined $timeout ? ($timeout ? $timeout/1000 : 0) : undef));

    @callbacks = ();
    if ($n > 0) {
	push @callbacks, $self->_dispatch_fd("read", $ro);
	push @callbacks, $self->_dispatch_fd("write", $wo);
	push @callbacks, $self->_dispatch_fd("exception", $eo);
    }
    push @callbacks, $self->_dispatch_timeout($self->_now);
    #push @callbacks, $self->_dispatch_hook();

    foreach my $callback (@callbacks) {
	$callback->invoke;
    }

    return 1;
}

sub _now {
    my $self = shift;

    my @now = gettimeofday;

    return $now[0] * 1000 + (($now[1] - ($now[1] % 1000)) / 1000);
}

sub _bits {
    my $self = shift;
    my $type = shift;
    my $vec = '';

    my $count = 0;
    foreach (keys %{$self->{fds}->{$type}}) {
	next unless $self->{fds}->{$type}->{$_}->{enabled};

	$count++;
	vec($vec, $_, 1) = 1;
    }
    return ($vec, $count);
}

sub _timeout {
    my $self = shift;
    my $now = shift;

    my $timeout;
    foreach (@{$self->{timeouts}}) {
	next unless defined && $_->{enabled};

	my $expired = $now - $_->{last_fired};
	# In case the clock was moved we handle $expired being < 0 (see t/26-reactor-time-adjusted.t)
	$expired = 0 if ($expired < 0);
	my $interval = ($expired > $_->{interval} ? 0 : $_->{interval} - $expired);
	$timeout = $interval if !(defined $timeout) ||
	    ($interval < $timeout);
    }
    return $timeout;
}


sub _dispatch_fd {
    my $self = shift;
    my $type = shift;
    my $vec = shift;

    my @callbacks;
    foreach my $fd (keys %{$self->{fds}->{$type}}) {
	next unless $self->{fds}->{$type}->{$fd}->{enabled};

	if (vec($vec, $fd, 1)) {
	    my $rec = $self->{fds}->{$type}->{$fd};
	
	    push @callbacks, $self->{fds}->{$type}->{$fd}->{callback};
	}
    }
    return @callbacks;
}


sub _dispatch_timeout {
    my $self = shift;
    my $now = shift;

    my @callbacks;
    foreach my $timeout (@{$self->{timeouts}}) {
	next unless defined($timeout) && $timeout->{enabled};
	my $expired = $now - $timeout->{last_fired};
	# if system clock was adjusted last_fired can be in the future
	# (see t/26-reactor-time-adjusted.t)
	$expired = $timeout->{interval} if ($expired < 0);

	# Select typically returns a little (0-10 ms) before we
	# asked it for. (8 milliseconds seems reasonable balance
	# between early timeouts & extra select calls
	if ($expired >= ($timeout->{interval}-8)) {
	    $timeout->{last_fired} = $now;
	    push @callbacks, $timeout->{callback};
	}
    }
    return @callbacks;
}


sub _dispatch_hook {
    my $self = shift;
    my $now = shift;

    my @callbacks;
    foreach my $hook (@{$self->{hooks}}) {
	next unless $hook->{enabled};
	push @callbacks, $hook->{callback};
    }
    return @callbacks;
}


=item $reactor->add_read($fd, $callback[, $status]);

Registers a file handle for monitoring of read
events. The C<$callback> parameter specifies either
a code reference to a subroutine, or an instance of
the C<Net::DBus::Callback> object to invoke each time
an event occurs. The optional C<$status> parameter is
a boolean value to specify whether the watch is
initially enabled.

=cut

sub add_read {
    my $self = shift;
    $self->_add("read", @_);
}

=item $reactor->add_write($fd, $callback[, $status]);

Registers a file handle for monitoring of write
events. The C<$callback> parameter specifies either
a code reference to a subroutine, or an
instance of the C<Net::DBus::Callback> object to invoke
each time an event occurs. The optional C<$status>
parameter is a boolean value to specify whether the
watch is initially enabled.

=cut

sub add_write {
    my $self = shift;
    $self->_add("write", @_);
}


=item $reactor->add_exception($fd, $callback[, $status]);

Registers a file handle for monitoring of exception
events. The C<$callback> parameter specifies either
a code reference to a subroutine, or  an
instance of the C<Net::DBus::Callback> object to invoke
each time an event occurs. The optional C<$status>
parameter is a boolean value to specify whether the
watch is initially enabled.

=cut

sub add_exception {
    my $self = shift;
    $self->_add("exception", @_);
}


=item my $id = $reactor->add_timeout($interval, $callback, $status);

Registers a new timeout to expire every C<$interval>
milliseconds. The C<$callback> parameter specifies either
a code reference to a subroutine, or an
instance of the C<Net::DBus::Callback> object to invoke
each time the timeout expires. The optional C<$status>
parameter is a boolean value to specify whether the
timeout is initially enabled. The return parameter is
a unique identifier which can be used to later remove
or disable the timeout.

=cut

sub add_timeout {
    my $self = shift;
    my $interval = shift;
    my $callback = shift;
    my $enabled = shift;
    $enabled = 1 unless defined $enabled;

    if (ref($callback) eq "CODE") {
	$callback = Net::DBus::Callback->new(method => $callback);
    }

    my $key;
    for (my $i = 0 ; $i <= $#{$self->{timeouts}} && !(defined $key); $i++) {
	$key = $i unless defined $self->{timeouts}->[$i];
    }
    $key = $#{$self->{timeouts}}+1 unless defined $key;

    $self->{timeouts}->[$key] = {
	interval => $interval,
	last_fired => $self->_now,
	callback => $callback,
	enabled => $enabled
	};

    return $key;
}


=item $reactor->remove_timeout($id);

Removes a previously registered timeout specified by
the C<$id> parameter.

=cut

sub remove_timeout {
    my $self = shift;
    my $key = shift;

    die "no timeout active with key '$key'"
	unless defined $self->{timeouts}->[$key];

    $self->{timeouts}->[$key] = undef;
}


=item $reactor->toggle_timeout($id, $status[, $interval]);

Updates the state of a previously registered timeout
specified by the C<$id> parameter. The C<$status>
parameter specifies whether the timeout is to be enabled
or disabled, while the optional C<$interval> parameter
can be used to change the period of the timeout.

=cut

sub toggle_timeout {
    my $self = shift;
    my $key = shift;
    my $enabled = shift;

    die "no timeout active with key '$key'"
	unless defined $self->{timeouts}->[$key];

    $self->{timeouts}->[$key]->{enabled} = $enabled;
    $self->{timeouts}->[$key]->{interval} = shift if @_;
}


=item my $id = $reactor->add_hook($callback[, $status]);

Registers a new hook to be fired on each iteration
of the event loop. The C<$callback> parameter
specifies  either a code reference to a subroutine, or
an instance of the C<Net::DBus::Callback>
class to invoke. The C<$status> parameter determines
whether the hook is initially enabled, or disabled.
The return parameter is a unique id which should
be used to later remove, or disable the hook.

=cut

sub add_hook {
    my $self = shift;
    my $callback = shift;
    my $enabled = shift;
    $enabled = 1 unless defined $enabled;

    if (ref($callback) eq "CODE") {
	$callback = Net::DBus::Callback->new(method => $callback);
    }

    my $key;
    for (my $i = 0 ; $i <= $#{$self->{hooks}} && !(defined $key); $i++) {
	$key = $i unless defined $self->{hooks}->[$i];
    }
    $key = $#{$self->{hooks}}+1 unless defined $key;

    $self->{hooks}->[$key] = {
	callback => $callback,
	enabled => $enabled
	};

    return $key;
}


=item $reactor->remove_hook($id)

Removes the previously registered hook identified
by C<$id>.

=cut

sub remove_hook {
    my $self = shift;
    my $key = shift;

    die "no hook present with key '$key'"
	unless defined $self->{hooks}->[$key];


    $self->{hooks}->[$key] = undef;
}

=item $reactor->toggle_hook($id, $status)

Updates the status of the previously registered
hook identified by C<$id>. The C<$status> parameter
determines whether the hook is to be enabled or
disabled.

=cut

sub toggle_hook {
    my $self = shift;
    my $key = shift;
    my $enabled = shift;

    $self->{hooks}->[$key]->{enabled} = $enabled;
}

sub _add {
    my $self = shift;
    my $type = shift;
    my $fd = shift;
    my $callback = shift;
    my $enabled = shift;
    $enabled = 1 unless defined $enabled;

    if (ref($callback) eq "CODE") {
	$callback = Net::DBus::Callback->new(method => $callback);
    }

    $self->{fds}->{$type}->{$fd} = {
	callback => $callback,
	enabled => $enabled
	};
}

=item $reactor->remove_read($fd);

=item $reactor->remove_write($fd);

=item $reactor->remove_exception($fd);

Removes a watch on the file handle C<$fd>.

=cut

sub remove_read {
    my $self = shift;
    $self->_remove("read", @_);
}

sub remove_write {
    my $self = shift;
    $self->_remove("write", @_);
}

sub remove_exception {
    my $self = shift;
    $self->_remove("exception", @_);
}

sub _remove {
    my $self = shift;
    my $type = shift;
    my $fd = shift;

    die "no handle ($type) active with fd '$fd'"
	unless exists $self->{fds}->{$type}->{$fd};

    delete $self->{fds}->{$type}->{$fd};
}

=item $reactor->toggle_read($fd, $status);

=item $reactor->toggle_write($fd, $status);

=item $reactor->toggle_exception($fd, $status);

Updates the status of a watch on the file handle C<$fd>.
The C<$status> parameter species whether the watch is
to be enabled or disabled.

=cut

sub toggle_read {
    my $self = shift;
    $self->_toggle("read", @_);
}

sub toggle_write {
    my $self = shift;
    $self->_toggle("write", @_);
}

sub toggle_exception {
    my $self = shift;
    $self->_toggle("exception", @_);
}

sub _toggle {
    my $self = shift;
    my $type = shift;
    my $fd = shift;
    my $enabled = shift;

    $self->{fds}->{$type}->{$fd}->{enabled} = $enabled;
}


1;

=pod

=back

=head1 SEE ALSO

L<Net::DBus::Callback>, L<Net::DBus::Connection>, L<Net::DBus::Server>

=head1 AUTHOR

Daniel Berrange E<lt>dan@berrange.comE<gt>

=head1 COPYRIGHT

Copyright 2004-2011 by Daniel Berrange

=cut
