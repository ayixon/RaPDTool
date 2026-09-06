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

Net::DBus::Exporter - Export object methods and signals to the bus

=head1 SYNOPSIS

  # Define a new package for the object we're going
  # to export
  package Demo::HelloWorld;

  # Specify the main interface provided by our object
  use Net::DBus::Exporter qw(org.example.demo.Greeter);

  # We're going to be a DBus object
  use base qw(Net::DBus::Object);

  # Ensure only explicitly exported methods can be invoked
  dbus_strict_exports;

  # Export a 'Greeting' signal taking a stringl string parameter
  dbus_signal("Greeting", ["string"]);

  # Export 'Hello' as a method accepting a single string
  # parameter, and returning a single string value
  dbus_method("Hello", ["string"], ["string"]);

  # Export 'Goodbye' as a method accepting a single string
  # parameter, and returning a single string, but put it
  # in the 'org.exaple.demo.Farewell' interface
  dbus_method("Goodbye", ["string"], ["string"], "org.example.demo.Farewell");

=head1 DESCRIPTION

The C<Net::DBus::Exporter> module is used to export methods
and signals defined in an object to the message bus. Since
Perl is a loosely typed language it is not possible to automatically
determine correct type information for methods to be exported.
Thus when sub-classing L<Net::DBus::Object>, this package will
provide the type information for methods and signals.

When importing this package, an optional argument can be supplied
to specify the default interface name to associate with methods
and signals, for which an explicit interface is not specified.
Thus in the common case of objects only providing a single interface,
this removes the need to repeat the interface name against each
method exported.

=head1 SCALAR TYPES

When specifying scalar data types for parameters and return values,
the following string constants must be used to denote the data
type. When values corresponding to these types are (un)marshalled
they are represented as the Perl SCALAR data type (see L<perldata>).

=over 4

=item "string"

A UTF-8 string of characters

=item "int16"

A 16-bit signed integer

=item "uint16"

A 16-bit unsigned integer

=item "int32"

A 32-bit signed integer

=item "uint32"

A 32-bit unsigned integer

=item "int64"

A 64-bit signed integer. NB, this type is not supported by
many builds of Perl on 32-bit platforms, so if used, your
data is liable to be truncated at 32-bits.

=item "uint64"

A 64-bit unsigned integer. NB, this type is not supported by
many builds of Perl on 32-bit platforms, so if used, your
data is liable to be truncated at 32-bits.

=item "byte"

A single 8-bit byte

=item "bool"

A boolean value

=item "double"

An IEEE double-precision floating point

=back

=head1 COMPOUND TYPES

When specifying compound data types for parameters and return
values, an array reference must be used, with the first element
being the name of the compound type.

=over 4

=item ["array", ARRAY-TYPE]

An array of values, whose type os C<ARRAY-TYPE>. The C<ARRAY-TYPE>
can be either a scalar type name, or a nested compound type. When
values corresponding to the array type are (un)marshalled, they
are represented as the Perl ARRAY data type (see L<perldata>). If,
for example, a method was declared to have a single parameter with
the type, ["array", "string"], then when calling the method one
would provide a array reference of strings:

    $object->hello(["John", "Doe"])

=item ["dict", KEY-TYPE, VALUE-TYPE]

A dictionary of values, more commonly known as a hash table. The
C<KEY-TYPE> is the name of the scalar data type used for the dictionary
keys. The C<VALUE-TYPE> is the name of the scalar, or compound
data type used for the dictionary values. When values corresponding
to the dict type are (un)marshalled, they are represented as the
Perl HASH data type (see L<perldata>). If, for example, a method was
declared to have a single parameter with the type ["dict", "string", "string"],
then when calling the method one would provide a hash reference
of strings,

   $object->hello({forename => "John", surname => "Doe"});

=item ["struct", VALUE-TYPE-1, VALUE-TYPE-2]

A structure of values, best thought of as a variation on the array
type where the elements can vary. Many languages have an explicit
name associated with each value, but since Perl does not have a
native representation of structures, they are represented by the
LIST data type. If, for exaple, a method was declared to have a single
parameter with the type ["struct", "string", "string"], corresponding
to the C structure

    struct {
      char *forename;
      char *surname;
    } name;

then, when calling the method one would provide an array reference
with the values orded to match the structure

   $object->hello(["John", "Doe"]);

=back

=head1 MAGIC TYPES

When specifying introspection data for an exported service, there
are a couple of so called C<magic> types. Parameters declared as
magic types are not visible to clients, but instead their values
are provided automatically by the server side bindings. One use of
magic types is to get an extra parameter passed with the unique
name of the caller invoking the method.

=over 4

=item "caller"

The value passed in is the unique name of the caller of the method.
Unique names are strings automatically assigned to client connections
by the bus daemon, for example ':1.15'

=item "serial"

The value passed in is an integer within the scope of a caller, which
increments on every method call.

=back

=head1 ANNOTATIONS

When exporting methods, signals & properties, in addition to the core
data typing information, a number of metadata annotations are possible.
These are specified by passing a hash reference with the desired keys
as the last parameter when defining the export. The following annotations
are currently supported

=over 4

=item no_return

Indicate that this method does not return any value, and thus no reply
message should be sent over the wire, likewise informing the clients
not to expect / wait for a reply message

=item deprecated

Indicate that use of this method/signal/property is discouraged, and
it may disappear altogether in a future release. Clients will typically
print out a warning message when a deprecated method/signal/property
is used.

=item param_names

An array of strings specifying names for the input parameters of the
method or signal. If omitted, no names will be assigned.

=item return_names

An array of strings specifying names for the return parameters of the
method. If omitted, no names will be assigned.

=item strict_exceptions

Exceptions thrown by this method which are not of type L<Net::DBus::Error> will
not be caught and converted to D-Bus errors. They will be rethrown and continue
up the stack until something else catches them (or the process dies).

=back

=head1 METHODS

=over 4

=cut

package Net::DBus::Exporter;

use vars qw(@ISA @EXPORT %dbus_exports %dbus_introspectors);

use Net::DBus::Binding::Introspector;

use warnings;
use strict;

use Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(dbus_method dbus_signal dbus_property dbus_no_strict_exports);


sub import {
    my $class = shift;

    my $caller = caller;
    if (exists $dbus_exports{$caller}) {
	warn "$caller is already registered with Net::DBus::Exporter";
	return;
    }

    $dbus_exports{$caller} = {
	strict => 1,
	methods => {},
	signals => {},
	props => {},
    };
    die "usage: use Net::DBus::Exporter 'interface-name';" unless @_;

    my $interface = shift;
    &_validate_interface($interface);
    $dbus_exports{$caller}->{interface} = $interface;

    $class->export_to_level(1, "", @EXPORT);
}

sub _dbus_introspector {
    my $class = shift;

    if (!exists $dbus_exports{$class}) {
	# If this class has not been exported, lets look
	# at the parent class & return its introspection
        # data instead.
	no strict 'refs';
	if (defined (*{"${class}::ISA"})) {
	    my @isa = @{"${class}::ISA"};
	    foreach my $parent (@isa) {
		# We don't recurse to Net::DBus::Object
		# since we need to give sub-classes the
		# choice of not supporting introspection
		next if $parent eq "Net::DBus::Object";

		my $ins = &_dbus_introspector($parent);
		if ($ins) {
		    return $ins;
		}
	    }
	}
	return undef;
    }

    unless (exists $dbus_introspectors{$class}) {
	my $is = Net::DBus::Binding::Introspector->new(strict=>$dbus_exports{$class}->{strict});
	&_dbus_introspector_add($class, $is);
	$dbus_introspectors{$class} = $is;
    }

    return $dbus_introspectors{$class};
}

sub _dbus_introspector_add {
    my $class = shift;
    my $introspector = shift;

    my $exports = $dbus_exports{$class};
    if ($exports) {
	foreach my $method (keys %{$exports->{methods}}) {
	    my ($params, $returns, $interface, $attributes, $paramnames, $returnnames) = @{$exports->{methods}->{$method}};
	    $introspector->add_method($method, $params, $returns, $interface, $attributes, $paramnames, $returnnames);
	}
	foreach my $prop (keys %{$exports->{props}}) {
	    my ($type, $access, $interface, $attributes) = @{$exports->{props}->{$prop}};
	    $introspector->add_property($prop, $type, $access, $interface, $attributes);
	}
	foreach my $signal (keys %{$exports->{signals}}) {
	    my ($params, $interface, $attributes, $paramnames) = @{$exports->{signals}->{$signal}};
	    $introspector->add_signal($signal, $params, $interface, $attributes, $paramnames);
	}
    }

    if (defined (*{"${class}::ISA"})) {
	no strict "refs";
	my @isa = @{"${class}::ISA"};
	foreach my $parent (@isa) {
	    &_dbus_introspector_add($parent, $introspector);
	}
    }
}

=item dbus_method($name, $params, $returns, [\%annotations]);

=item dbus_method($name, $params, $returns, $interface, [\%annotations]);

Exports a method called C<$name>, having parameters whose types
are defined by C<$params>, and returning values whose types are
defined by C<$returns>. If the C<$interface> parameter is
provided, then the method is associated with that interface, otherwise
the default interface for the calling package is used. The
value for the C<$params> parameter should be an array reference
with each element defining the data type of a parameter to the
method. Likewise, the C<$returns> parameter should be an array
reference with each element defining the data type of a return
value. If it not possible to export a method which accepts a
variable number of parameters, or returns a variable number of
values.

=cut

sub dbus_method {
    my $name = shift;
    my $params = [];
    my $returns = [];
    my $caller = caller;
    my $interface = $dbus_exports{$caller}->{interface};
    my %attributes;

    if (@_ && ref($_[0]) eq "ARRAY") {
	$params = shift;
    }
    if (@_ && ref($_[0]) eq "ARRAY") {
	$returns = shift;
    }
    if (@_ && !ref($_[0])) {
	$interface = shift;
	&_validate_interface($interface);
    }
    if (@_ && ref($_[0]) eq "HASH") {
	%attributes = %{$_[0]};
    }

    if (!$interface) {
	die "interface not specified & no default interface defined";
    }

    my $param_names = [];
    if ( $attributes{param_names} ) {
      $param_names = $attributes{param_names} if ref($attributes{param_names}) eq "ARRAY";
      delete($attributes{param_names});
    }
    my $return_names = [];
    if ( $attributes{return_names} ) {
      $return_names = $attributes{return_names} if ref($attributes{return_names}) eq "ARRAY";
      delete($attributes{return_names});
    }

    $dbus_exports{$caller}->{methods}->{$name} = [$params, $returns, $interface, \%attributes, $param_names, $return_names];
}

=item dbus_no_strict_exports();

If a object is using the Exporter to generate DBus introspection data,
the default behaviour is to only allow invocation of methods which have
been explicitly exported.

To allow clients to access methods which have not been explicitly
exported, call C<dbus_no_strict_exports>. NB, doing this may be
a security risk if you have methods considered to be "private" for
internal use only. As such this method should not normally be used.
It is here only to allow switching export behaviour to match earlier
releases.

=cut

sub dbus_no_strict_exports {
    my $caller = caller;
    $dbus_exports{$caller}->{strict} = 0;
}

=item dbus_property($name, $type, $access, [\%attributes]);

=item dbus_property($name, $type, $access, $interface, [\%attributes]);

Exports a property called C<$name>, whose data type is C<$type>.
If the C<$interface> parameter is provided, then the property is
associated with that interface, otherwise the default interface
for the calling package is used.

=cut

sub dbus_property {
    my $name = shift;
    my $type = "string";
    my $access = "readwrite";
    my $caller = caller;
    my $interface = $dbus_exports{$caller}->{interface};
    my %attributes;

    if (@_ && (!ref($_[0]) || (ref($_[0]) eq "ARRAY"))) {
	$type = shift;
    }
    if (@_ && !ref($_[0])) {
	$access = shift;
    }
    if (@_ && !ref($_[0])) {
	$interface = shift;
	&_validate_interface($interface);
    }
    if ($_ && ref($_[0]) eq "HASH") {
	%attributes = %{$_[0]};
    }

    if (!$interface) {
	die "interface not specified & no default interface defined";
    }

    $dbus_exports{$caller}->{props}->{$name} = [$type, $access, $interface, \%attributes];
}


=item dbus_signal($name, $params, [\%attributes]);

=item dbus_signal($name, $params, $interface, [\%attributes]);

Exports a signal called C<$name>, having parameters whose types
are defined by C<$params>. If the C<$interface> parameter is
provided, then the signal is associated with that interface, otherwise
the default interface for the calling package is used. The
value for the C<$params> parameter should be an array reference
with each element defining the data type of a parameter to the
signal. Signals do not have return values. It not possible to
export a signal which has a variable number of parameters.

=cut

sub dbus_signal {
    my $name = shift;
    my $params = [];
    my $caller = caller;
    my $interface = $dbus_exports{$caller}->{interface};
    my %attributes;

    if (@_ && ref($_[0]) eq "ARRAY") {
	$params = shift;
    }
    if (@_ && !ref($_[0])) {
	$interface = shift;
	&_validate_interface($interface);
    }
    if (@_ && ref($_[0]) eq "HASH") {
	%attributes = %{$_[0]};
    }

    if (!$interface) {
	die "interface not specified & no default interface defined";
    }

    my $param_names = [];
    if ( $attributes{param_names} ) {
      $param_names = $attributes{param_names} if ref($attributes{param_names}) eq "ARRAY";
      delete($attributes{param_names});
    }

    $dbus_exports{$caller}->{signals}->{$name} = [$params, $interface, \%attributes, $param_names];
}


sub _validate_interface {
    my $interface = shift;

    die "interface name '$interface' is not valid.\n" .
	" * Interface names are composed of 1 or more elements separated by a\n" .
	"   period ('.') character. All elements must contain at least one character.\n" .
	" * Each element must only contain the ASCII characters '[A-Z][a-z][0-9]_'\n" .
	"   and must not begin with a digit.\n" .
	" * Interface names must contain at least one '.' (period) character (and\n" .
	"   thus at least two elements).\n" .
	" * Interface names must not begin with a '.' (period) character.\n"
    	unless $interface =~ /^[a-zA-Z_]\w*(\.[a-zA-Z_]\w*)+$/;
}

1;

=back

=head1 EXAMPLES

=over 4

=item No parameters, no return values

A method which simply prints "Hello World" each time its called

   sub Hello {
       my $self = shift;
       print "Hello World\n";
   }

   dbus_method("Hello", [], []);

=item One string parameter, returning an boolean value

A method which accepts a process name, issues the killall
command on it, and returns a boolean value to indicate whether
it was successful.

   sub KillAll {
       my $self = shift;
       my $processname = shift;
       my $ret  = system("killall $processname");
       return $ret == 0 ? 1 : 0;
   }

   dbus_method("KillAll", ["string"], ["bool"]);

=item One list of strings parameter, returning a dictionary

A method which accepts a list of files names, stats them, and
returns a dictionary containing the last modification times.

    sub LastModified {
       my $self = shift;
       my $files = shift;

       my %mods;
       foreach my $file (@{$files}) {
          $mods{$file} = (stat $file)[9];
       }
       return \%mods;
    }

    dbus_method("LastModified", ["array", "string"], ["dict", "string", "int32"]);

=item Annotating methods with metdata

A method which is targeted for removal, and also does not
return any value

    sub PlayMP3 {
	my $self = shift;
        my $track = shift;

        system "mpg123 $track &";
    }

    dbus_method("PlayMP3", ["string"], [], { deprecated => 1, no_return => 1 });

Or giving names to input parameters:

    sub PlayMP3 {
	my $self = shift;
        my $track = shift;

        system "mpg123 $track &";
    }

    dbus_method("PlayMP3", ["string"], [], { param_names => ["track"] });

=back

=head1 AUTHOR

Daniel P. Berrange <dan@berrange.com>

=head1 COPYRIGHT

Copright (C) 2004-2011, Daniel Berrange.

=head1 SEE ALSO

L<Net::DBus::Object>, L<Net::DBus::Binding::Introspector>

=cut
