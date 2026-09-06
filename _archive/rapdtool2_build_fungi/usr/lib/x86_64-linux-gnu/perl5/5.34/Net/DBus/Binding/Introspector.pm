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

Net::DBus::Binding::Introspector - Handler for object introspection data

=head1 SYNOPSIS

  # Create an object populating with info from an
  # XML doc containing introspection data.

  my $ins = Net::DBus::Binding::Introspector->new(xml => $data);

  # Create an object, defining introspection data
  # programmatically
  my $ins = Net::DBus::Binding::Introspector->new(object_path => $object->get_object_path);
  $ins->add_method("DoSomething", ["string"], [], "org.example.MyObject");
  $ins->add_method("TestSomething", ["int32"], [], "org.example.MyObject");

=head1 DESCRIPTION

This class is responsible for managing introspection data, and
answering questions about it. This is not intended for use by
application developers, whom should instead consult the higher
level API in L<Net::DBus::Exporter>.

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Introspector;

use 5.006;
use strict;
use warnings;

use XML::Twig;

use Net::DBus::Binding::Message;

our $debug = 0;

BEGIN {
    if ($ENV{NET_DBUS_DEBUG} &&
	$ENV{NET_DBUS_DEBUG} eq "introspect") {
	$debug = 1;
    }
}

our %simple_type_map = (
  "byte" => &Net::DBus::Binding::Message::TYPE_BYTE,
  "bool" => &Net::DBus::Binding::Message::TYPE_BOOLEAN,
  "double" => &Net::DBus::Binding::Message::TYPE_DOUBLE,
  "string" => &Net::DBus::Binding::Message::TYPE_STRING,
  "int16" => &Net::DBus::Binding::Message::TYPE_INT16,
  "uint16" => &Net::DBus::Binding::Message::TYPE_UINT16,
  "int32" => &Net::DBus::Binding::Message::TYPE_INT32,
  "uint32" => &Net::DBus::Binding::Message::TYPE_UINT32,
  "int64" => &Net::DBus::Binding::Message::TYPE_INT64,
  "uint64" => &Net::DBus::Binding::Message::TYPE_UINT64,
  "objectpath" => &Net::DBus::Binding::Message::TYPE_OBJECT_PATH,
  "signature" => &Net::DBus::Binding::Message::TYPE_SIGNATURE,
  "unixfd" => &Net::DBus::Binding::Message::TYPE_UNIX_FD,
);

our %simple_type_rev_map = (
  &Net::DBus::Binding::Message::TYPE_BYTE => "byte",
  &Net::DBus::Binding::Message::TYPE_BOOLEAN => "bool",
  &Net::DBus::Binding::Message::TYPE_DOUBLE => "double",
  &Net::DBus::Binding::Message::TYPE_STRING => "string",
  &Net::DBus::Binding::Message::TYPE_INT16 => "int16",
  &Net::DBus::Binding::Message::TYPE_UINT16 => "uint16",
  &Net::DBus::Binding::Message::TYPE_INT32 => "int32",
  &Net::DBus::Binding::Message::TYPE_UINT32 => "uint32",
  &Net::DBus::Binding::Message::TYPE_INT64 => "int64",
  &Net::DBus::Binding::Message::TYPE_UINT64 => "uint64",
  &Net::DBus::Binding::Message::TYPE_OBJECT_PATH => "objectpath",
  &Net::DBus::Binding::Message::TYPE_SIGNATURE => "signature",
  &Net::DBus::Binding::Message::TYPE_UNIX_FD => "unixfd",
);

our %magic_type_map = (
  "caller" => sub {
    my $msg = shift;

    return $msg->get_sender;
  },
  "serial" => sub {
    my $msg = shift;

    return $msg->get_serial;
  },
);

our %compound_type_map = (
  "array" => &Net::DBus::Binding::Message::TYPE_ARRAY,
  "struct" => &Net::DBus::Binding::Message::TYPE_STRUCT,
  "dict" => &Net::DBus::Binding::Message::TYPE_DICT_ENTRY,
  "variant" => &Net::DBus::Binding::Message::TYPE_VARIANT,
);

=item my $ins = Net::DBus::Binding::Introspector->new(object_path => $object_path,
						      xml => $xml);

Creates a new introspection data manager for the object registered
at the path specified for the C<object_path> parameter. The optional
C<xml> parameter can be used to pre-load the manager with introspection
metadata from an XML document.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{interfaces} = {};

    bless $self, $class;

    if (defined $params{xml}) {
	$self->{object_path} = exists $params{object_path} ? $params{object_path} : undef;
	$self->_parse($params{xml});
    } elsif (defined $params{node}) {
	$self->{object_path} = exists $params{object_path} ? $params{object_path} : undef;
	$self->_parse_node($params{node});
    } else {
	$self->{object_path} = exists $params{object_path} ? $params{object_path} : undef;
	$self->{interfaces} = $params{interfaces} if exists $params{interfaces};
	$self->{children} = exists $params{children} ? $params{children} : [];
    }

    $self->{strict} = exists $params{strict} ? $params{strict} : 0;

    # Some versions of dbus failed to include signals in introspection data
    # so this code adds them, letting us keep compatability with old versions
    if (defined $self->{object_path} &&
	$self->{object_path} eq "/org/freedesktop/DBus") {
	if (!$self->has_signal("NameOwnerChanged")) {
	    $self->add_signal("NameOwnerChanged", ["string","string","string"], "org.freedesktop.DBus");
	}
	if (!$self->has_signal("NameLost")) {
	    $self->add_signal("NameLost", ["string"], "org.freedesktop.DBus");
	}
	if (!$self->has_signal("NameAcquired")) {
	    $self->add_signal("NameAcquired", ["string"], "org.freedesktop.DBus");
	}
    }

    return $self;
}

=item $ins->add_interface($name)

Register the object as providing an interface with the name C<$name>

=cut

sub add_interface {
    my $self = shift;
    my $name = shift;

    $self->{interfaces}->{$name} = {
	methods => {},
	signals => {},
	props => {},
    } unless exists $self->{interfaces}->{$name};
}

=item my $bool = $ins->has_interface($name)

Return a true value if the object is registered as providing
an interface with the name C<$name>; returns false otherwise.

=cut

sub has_interface {
    my $self = shift;
    my $name = shift;

    return exists $self->{interfaces}->{$name} ? 1 : 0;
}

=item my @interfaces = $ins->has_method($name, [$interface])

Return a list of all interfaces provided by the object, which
contain a method called C<$name>. This may be an empty list.
The optional C<$interface> parameter can restrict the check to
just that one interface.

=cut

sub has_method {
    my $self = shift;
    my $name = shift;

    if (@_) {
	my $interface = shift;
	return () unless exists $self->{interfaces}->{$interface};
	return () unless exists $self->{interfaces}->{$interface}->{methods}->{$name};
	return ($interface);
    } else {
	my @interfaces;
	foreach my $interface (keys %{$self->{interfaces}}) {
	    if (exists $self->{interfaces}->{$interface}->{methods}->{$name}) {
		push @interfaces, $interface;
	    }
	}
	return @interfaces;
    }
}

=item my $boolean = $ins->is_method_allowed($name[, $interface])

Checks according to whether the remote caller is allowed to invoke
the method C<$name> on the object associated with this introspector.
If this object has 'strict exports' enabled, then only explicitly
exported methods will be allowed. The optional C<$interface> parameter
can restrict the check to just that one interface. Returns a non-zero
value if the method should be allowed.

=cut

sub is_method_allowed {
    my $self = shift;
    my $name = shift;

    if ($self->{strict}) {
	return $self->has_method($name, @_) ? 1 : 0;
    } else {
	return 1;
    }
}

=item my @interfaces = $ins->has_signal($name)

Return a list of all interfaces provided by the object, which
contain a signal called C<$name>. This may be an empty list.

=cut

sub has_signal {
    my $self = shift;
    my $name = shift;

    my @interfaces;
    foreach my $interface (keys %{$self->{interfaces}}) {
	if (exists $self->{interfaces}->{$interface}->{signals}->{$name}) {
	    push @interfaces, $interface;
	}
    }
    return @interfaces;
}

=item my @interfaces = $ins->has_property($name)

Return a list of all interfaces provided by the object, which
contain a property called C<$name>. This may be an empty list.
The optional C<$interface> parameter can restrict the check to
just that one interface.

=cut

sub has_property {
    my $self = shift;
    my $name = shift;

    if (@_) {
	my $interface = shift;
	return () unless exists $self->{interfaces}->{$interface};
	return () unless exists $self->{interfaces}->{$interface}->{props}->{$name};
	return ($interface);
    } else {
	my @interfaces;
	foreach my $interface (keys %{$self->{interfaces}}) {
	    if (exists $self->{interfaces}->{$interface}->{props}->{$name}) {
		push @interfaces, $interface;
	    }
	}
	return @interfaces;
    }
}

=item $ins->add_method($name, $params, $returns, $interface, $attributes, $paramnames, $returnnames);

Register the object as providing a method called C<$name> accepting parameters
whose types are declared by C<$params> and returning values whose type
are declared by C<$returns>. The method will be scoped to the interface
named by C<$interface>. The C<$attributes> parameter is a hash reference
for annotating the method. The C<$paramnames> and C<$returnames> parameters
are a list of argument and return value names.

=cut

sub add_method {
    my $self = shift;
    my $name = shift;
    my $params = shift;
    my $returns = shift;
    my $interface = shift;
    my $attributes = shift;
    my $paramnames = shift;
    my $returnnames = shift;

    $self->add_interface($interface);
    $self->{interfaces}->{$interface}->{methods}->{$name} = {
	params => $params,
	returns => $returns,
	paramnames => $paramnames,
	returnnames => $returnnames,
	deprecated => $attributes->{deprecated} ? 1 : 0,
	no_reply => $attributes->{no_return} ? 1 : 0,
	strict_exceptions => $attributes->{strict_exceptions} ? 1 : 0,
    };
}

=item $ins->add_signal($name, $params, $interface, $attributes);

Register the object as providing a signal called C<$name> with parameters
whose types are declared by C<$params>. The signal will be scoped to the interface
named by C<$interface>. The C<$attributes> parameter is a hash reference
for annotating the signal.

=cut

sub add_signal {
    my $self = shift;
    my $name = shift;
    my $params = shift;
    my $interface = shift;
    my $attributes = shift;
    my $paramnames = shift;

    $self->add_interface($interface);
    $self->{interfaces}->{$interface}->{signals}->{$name} = {
	params => $params,
	paramnames => $paramnames,
	deprecated => $attributes->{deprecated} ? 1 : 0,
    };
}

=item $ins->add_property($name, $type, $access, $interface, $attributes);

Register the object as providing a property called C<$name> with a type
of C<$type>. The C<$access> parameter can be one of C<read>, C<write>,
or C<readwrite>. The property will be scoped to the interface
named by C<$interface>. The C<$attributes> parameter is a hash reference
for annotating the signal.

=cut

sub add_property {
    my $self = shift;
    my $name = shift;
    my $type = shift;
    my $access = shift;
    my $interface = shift;
    my $attributes = shift;

    $self->add_interface($interface);
    $self->{interfaces}->{$interface}->{props}->{$name} = {
	type => $type,
	access => $access,
	deprecated => $attributes->{deprecated} ? 1 : 0,
    };
}

=item my $boolean = $ins->is_method_deprecated($name, $interface)

Returns a true value if the method called C<$name> in the interface
C<$interface> is marked as deprecated

=cut

sub is_method_deprecated {
    my $self = shift;
    my $name = shift;
    my $interface = shift;

    die "no interface $interface" unless exists $self->{interfaces}->{$interface};
    die "no method $name in interface $interface" unless exists $self->{interfaces}->{$interface}->{methods}->{$name};
    return 1 if $self->{interfaces}->{$interface}->{methods}->{$name}->{deprecated};
    return 0;
}

=item my $boolean = $ins->is_signal_deprecated($name, $interface)

Returns a true value if the signal called C<$name> in the interface
C<$interface> is marked as deprecated

=cut

sub is_signal_deprecated {
    my $self = shift;
    my $name = shift;
    my $interface = shift;

    die "no interface $interface" unless exists $self->{interfaces}->{$interface};
    die "no signal $name in interface $interface" unless exists $self->{interfaces}->{$interface}->{signals}->{$name};
    return 1 if $self->{interfaces}->{$interface}->{signals}->{$name}->{deprecated};
    return 0;
}

=item my $boolean = $ins->is_property_deprecated($name, $interface)

Returns a true value if the property called C<$name> in the interface
C<$interface> is marked as deprecated

=cut

sub is_property_deprecated {
    my $self = shift;
    my $name = shift;
    my $interface = shift;

    die "no interface $interface" unless exists $self->{interfaces}->{$interface};
    die "no property $name in interface $interface" unless exists $self->{interfaces}->{$interface}->{props}->{$name};
    return 1 if $self->{interfaces}->{$interface}->{props}->{$name}->{deprecated};
    return 0;
}

=item my $boolean = $ins->does_method_reply($name, $interface)

Returns a true value if the method called C<$name> in the interface
C<$interface> will generate a reply. Returns a false value otherwise.

=cut

sub does_method_reply {
    my $self = shift;
    my $name = shift;
    my $interface = shift;

    die "no interface $interface" unless exists $self->{interfaces}->{$interface};
    die "no method $name in interface $interface" unless exists $self->{interfaces}->{$interface}->{methods}->{$name};
    return 0 if $self->{interfaces}->{$interface}->{methods}->{$name}->{no_reply};
    return 1;
}

=item my $boolean = $ins->method_has_strict_exceptions($name, $interface)

Returns true if the method called C<$name> in the interface C<$interface> has
the strict_exceptions attribute; that is any exceptions which aren't
L<Net::DBus::Error> objects should not be caught and allowed to travel up the
stack.

=cut

sub method_has_strict_exceptions {
    my $self = shift;
    my $name = shift;
    my $interface = shift;

    return 0 unless exists $self->{interfaces}->{$interface};
    return 0 unless exists $self->{interfaces}->{$interface}->{methods}->{$name};
    return 1 if $self->{interfaces}->{$interface}->{methods}->{$name}->{strict_exceptions};
    return 0;
}

=item my @names = $ins->list_interfaces

Returns a list of all interfaces registered as being provided
by the object.

=cut

sub list_interfaces {
    my $self = shift;

    return keys %{$self->{interfaces}};
}

=item my @names = $ins->list_methods($interface)

Returns a list of all methods registered as being provided
by the object, within the interface C<$interface>.

=cut

sub list_methods {
    my $self = shift;
    my $interface = shift;
    return keys %{$self->{interfaces}->{$interface}->{methods}};
}

=item my @names = $ins->list_signals($interface)

Returns a list of all signals registered as being provided
by the object, within the interface C<$interface>.

=cut

sub list_signals {
    my $self = shift;
    my $interface = shift;
    return keys %{$self->{interfaces}->{$interface}->{signals}};
}

=item my @names = $ins->list_properties($interface)

Returns a list of all properties registered as being provided
by the object, within the interface C<$interface>.

=cut

sub list_properties {
    my $self = shift;
    my $interface = shift;
    return keys %{$self->{interfaces}->{$interface}->{props}};
}

=item my @paths = $self->list_children;

Returns a list of object paths representing all the children
of this node.

=cut

sub list_children {
    my $self = shift;
    return @{$self->{children}};
}

=item my $path = $ins->get_object_path

Returns the path of the object associated with this introspection
data

=cut

sub get_object_path {
    my $self = shift;
    return $self->{object_path};
}

=item my @types = $ins->get_method_params($interface, $name)

Returns a list of declared data types for parameters of the
method called C<$name> within the interface C<$interface>.

=cut

sub get_method_params {
    my $self = shift;
    my $interface = shift;
    my $method = shift;
    return @{$self->{interfaces}->{$interface}->{methods}->{$method}->{params}};
}

=item my @types = $ins->get_method_param_names($interface, $name)

Returns a list of declared names for parameters of the
method called C<$name> within the interface C<$interface>.

=cut

sub get_method_param_names {
    my $self = shift;
    my $interface = shift;
    my $method = shift;
    return @{$self->{interfaces}->{$interface}->{methods}->{$method}->{paramnames}};
}

=item my @types = $ins->get_method_returns($interface, $name)

Returns a list of declared data types for return values of the
method called C<$name> within the interface C<$interface>.

=cut

sub get_method_returns {
    my $self = shift;
    my $interface = shift;
    my $method = shift;
    return @{$self->{interfaces}->{$interface}->{methods}->{$method}->{returns}};
}

=item my @types = $ins->get_method_return_names($interface, $name)

Returns a list of declared names for return values of the
method called C<$name> within the interface C<$interface>.

=cut

sub get_method_return_names {
    my $self = shift;
    my $interface = shift;
    my $method = shift;
    return @{$self->{interfaces}->{$interface}->{methods}->{$method}->{returnnames}};
}

=item my @types = $ins->get_signal_params($interface, $name)

Returns a list of declared data types for values associated with the
signal called C<$name> within the interface C<$interface>.

=cut

sub get_signal_params {
    my $self = shift;
    my $interface = shift;
    my $signal = shift;
    return @{$self->{interfaces}->{$interface}->{signals}->{$signal}->{params}};
}

=item my @types = $ins->get_signal_param_names($interface, $name)

Returns a list of declared names for values associated with the
signal called C<$name> within the interface C<$interface>.

=cut

sub get_signal_param_names {
    my $self = shift;
    my $interface = shift;
    my $signal = shift;
    return @{$self->{interfaces}->{$interface}->{signals}->{$signal}->{paramnames}};
}

=item my $type = $ins->get_property_type($interface, $name)

Returns the declared data type for property called C<$name> within
the interface C<$interface>.

=cut

sub get_property_type {
    my $self = shift;
    my $interface = shift;
    my $prop = shift;
    return $self->{interfaces}->{$interface}->{props}->{$prop}->{type};
}

=item my $bool = $ins->is_property_readable($interface, $name);

Returns a true value if the property called C<$name> within the
interface C<$interface> can have its value read.

=cut

sub is_property_readable {
    my $self = shift;
    my $interface = shift;
    my $prop = shift;
    my $access = $self->{interfaces}->{$interface}->{props}->{$prop}->{access};
    return $access eq "readwrite" || $access eq "read" ? 1 : 0;
}

=item my $bool = $ins->is_property_writable($interface, $name);

Returns a true value if the property called C<$name> within the
interface C<$interface> can have its value written to.

=cut

sub is_property_writable {
    my $self = shift;
    my $interface = shift;
    my $prop = shift;
    my $access = $self->{interfaces}->{$interface}->{props}->{$prop}->{access};
    return $access eq "readwrite" || $access eq "write" ? 1 : 0;
}

sub _parse {
    my $self = shift;
    my $xml = shift;

    my $twig = XML::Twig->new(no_xxe => 1);
    $twig->parse($xml);

    $self->_parse_node($twig->root);
}

sub _parse_node {
    my $self = shift;
    my $node = shift;

    $self->{object_path} = $node->att("name") if defined $node->att("name");
    die "no object path provided" unless defined $self->{object_path};
    $self->{children} = [];
    foreach my $child ($node->children("interface")) {
	$self->_parse_interface($child);
    }
    foreach my $child ($node->children("node")) {
	if (!$child->has_children()) {
	    push @{$self->{children}}, $child->att("name");
	} else {
	    push @{$self->{children}}, $self->new(node => $child);
	}
    }
}

sub _parse_interface {
    my $self = shift;
    my $node = shift;

    my $name = $node->att("name");
    $self->{interfaces}->{$name} = {
	methods => {},
	signals => {},
	props => {},
    };

    foreach my $child ($node->children("method")) {
	$self->_parse_method($child, $name);
    }
    foreach my $child ($node->children("signal")) {
	$self->_parse_signal($child, $name);
    }
    foreach my $child ($node->children("property")) {
	$self->_parse_property($child, $name);
    }
}

sub _parse_method {
    my $self = shift;
    my $node = shift;
    my $interface = shift;

    my $name = $node->att("name");
    my @params;
    my @returns;
    my @paramnames;
    my @returnnames;
    my $deprecated = 0;
    my $no_reply = 0;
    foreach my $child ($node->children("arg")) {
	my $type = $child->att("type");
	my $direction = $child->att("direction");
	my $name = $child->att("name");

	my @sig = split //, $type;
	my @type = $self->_parse_type(\@sig);
	if (!defined $direction || $direction eq "in") {
	    push @params, @type;
	    push @paramnames, $name;
	} elsif ($direction eq "out") {
	    push @returns, @type;
	    push @returnnames, $name;
	}
    }
    foreach my $child ($node->children("annotation")) {
	my $name = $child->att("name");
	my $value = $child->att("value");

	if ($name eq "org.freedesktop.DBus.Deprecated") {
	    $deprecated = 1 if lc($value) eq "true";
	} elsif ($name eq "org.freedesktop.DBus.Method.NoReply") {
	    $no_reply = 1 if lc($value) eq "true";
	}
    }

    $self->{interfaces}->{$interface}->{methods}->{$name} = {
	params => \@params,
	returns => \@returns,
	no_reply => $no_reply,
	deprecated => $deprecated,
	paramnames => \@paramnames,
	returnnames => \@returnnames,
    }
}

sub _parse_type {
    my $self = shift;
    my $sig = shift;

    my $root = [];
    my $current = $root;
    my @cont;
    while (my $type = shift @{$sig}) {
	if (exists $simple_type_rev_map{ord($type)}) {
	    push @{$current}, $simple_type_rev_map{ord($type)};
	    while ($current->[0] eq "array") {
		$current = pop @cont;
	    }
	} else {
	    if ($type eq "(") {
		my $new = ["struct"];
		push @{$current}, $new;
		push @cont, $current;
		$current = $new;
	    } elsif ($type eq "a") {
		my $new = ["array"];
		push @cont, $current;
		push @{$current}, $new;
		$current = $new;
	    } elsif ($type eq "{") {
		if ($current->[0] ne "array") {
		    die "dict must only occur within an array";
		}
		$current->[0] = "dict";
	    } elsif ($type eq ")") {
		die "unexpected end of struct" unless
		    $current->[0] eq "struct";
		$current = pop @cont;
		while ($current->[0] eq "array") {
		    $current = pop @cont;
		}
	    } elsif ($type eq "}") {
		die "unexpected end of dict" unless
		    $current->[0] eq "dict";
		$current = pop @cont;
		while ($current->[0] eq "array") {
		    $current = pop @cont;
		}
	    } elsif ($type eq "v") {
		push @{$current}, ["variant"];
		while ($current->[0] eq "array") {
		    $current = pop @cont;
		}
	    } else {
		die "unknown type sig '$type'";
	    }
	}
    }
    return @{$root};
}

sub _parse_signal {
    my $self = shift;
    my $node = shift;
    my $interface = shift;

    my $name = $node->att("name");
    my @params;
    my @paramnames;
    my $deprecated = 0;
    foreach my $child ($node->children("arg")) {
	my $type = $child->att("type");
	my $name = $child->att("name");
	my @sig = split //, $type;
	my @type = $self->_parse_type(\@sig);
	push @params, @type;
	push @paramnames, $name;
    }
    foreach my $child ($node->children("annotation")) {
	my $name = $child->att("name");
	my $value = $child->att("value");

	if ($name eq "org.freedesktop.DBus.Deprecated") {
	    $deprecated = 1 if lc($value) eq "true";
	}
    }

    $self->{interfaces}->{$interface}->{signals}->{$name} = {
	params => \@params,
	paramnames => \@paramnames,
	deprecated => $deprecated,
    };
}

sub _parse_property {
    my $self = shift;
    my $node = shift;
    my $interface = shift;

    my $name = $node->att("name");
    my $access = $node->att("access");
    my $deprecated = 0;

    foreach my $child ($node->children("annotation")) {
	my $name = $child->att("name");
	my $value = $child->att("value");

	if ($name eq "org.freedesktop.DBus.Deprecated") {
	    $deprecated = 1 if lc($value) eq "true";
	}
    }
    my @sig = split //, $node->att("type");
    $self->{interfaces}->{$interface}->{props}->{$name} = {
	type =>  $self->_parse_type(\@sig),
	access => $access,
	deprecated => $deprecated,
    };
}

=item my $xml = $ins->format([$obj])

Return a string containing an XML document representing the
state of the introspection data. The optional C<$obj> parameter
can be an instance of L<Net::DBus::Object> to include object
specific information in the XML (eg child nodes).

=cut

sub format {
    my $self = shift;
    my $obj = shift;

    my $xml = '<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"' . "\n";
    $xml .= '"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">' . "\n";

    return $xml . $self->to_xml("", $obj);
}

=item my $xml_fragment = $ins->to_xml

Returns a string containing an XML fragment representing the
state of the introspection data. This is basically the same
as the C<format> method, but without the leading doctype
declaration.

=cut

sub to_xml {
    my $self = shift;
    my $indent = shift;
    my $obj = shift;

    my $xml = '';
    my $path = $obj ? $obj->get_object_path : $self->{object_path};
    unless (defined $path) {
	die "no object_path for introspector, and no object supplied";
    }
    $xml .= $indent . '<node name="' . $path . '">' . "\n";

    foreach my $name (sort { $a cmp $b } keys %{$self->{interfaces}}) {
	my $interface = $self->{interfaces}->{$name};
	$xml .= $indent . '  <interface name="' . $name . '">' . "\n";
	foreach my $mname (sort { $a cmp $b } keys %{$interface->{methods}}) {
	    my $method = $interface->{methods}->{$mname};
	    $xml .= $indent . '    <method name="' . $mname . '">' . "\n";

	    my @paramnames = map{ $_ ? "name=\"$_\" " : '' } ( @{$method->{paramnames}} );
	    my @returnnames = map{ $_ ? "name=\"$_\" " : '' } ( @{$method->{returnnames}} );

	    foreach my $type (@{$method->{params}}) {
		next if ! ref($type) && exists $magic_type_map{$type};
		$xml .= $indent . '      <arg ' . (@paramnames ? shift(@paramnames) : "")
		    . 'type="' . $self->to_xml_type($type) . '" direction="in"/>' . "\n";
	    }

	    foreach my $type (@{$method->{returns}}) {
		next if ! ref($type) && exists $magic_type_map{$type};
		$xml .= $indent . '      <arg ' . (@returnnames ? shift(@returnnames) : "")
		    . 'type="' . $self->to_xml_type($type) . '" direction="out"/>' . "\n";
	    }
	    if ($method->{deprecated}) {
		$xml .= $indent . '      <annotation name="org.freedesktop.DBus.Deprecated" value="true"/>' . "\n";
	    }
	    if ($method->{no_reply}) {
		$xml .= $indent . '      <annotation name="org.freedesktop.DBus.Method.NoReply" value="true"/>' . "\n";
	    }
	    $xml .= $indent . '    </method>' . "\n";
	}
	foreach my $sname (sort { $a cmp $b } keys %{$interface->{signals}}) {
	    my $signal = $interface->{signals}->{$sname};
	    $xml .= $indent . '    <signal name="' . $sname . '">' . "\n";

	    my @paramnames = map{ $_ ? "name=\"$_\" " : '' } ( @{$signal->{paramnames}} );

	    foreach my $type (@{$signal->{params}}) {
		next if ! ref($type) && exists $magic_type_map{$type};
		$xml .= $indent . '      <arg ' . (@paramnames ? shift(@paramnames) : "")
		    . 'type="' . $self->to_xml_type($type) . '"/>' . "\n";
	    }
	    if ($signal->{deprecated}) {
		$xml .= $indent . '      <annotation name="org.freedesktop.DBus.Deprecated" value="true"/>' . "\n";
	    }
	    $xml .= $indent . '    </signal>' . "\n";
	}

	foreach my $pname (sort { $a cmp $b } keys %{$interface->{props}}) {
	    my $prop = $interface->{props}->{$pname};
	    my $type = $interface->{props}->{$pname}->{type};
	    my $access = $interface->{props}->{$pname}->{access};
	    if ($prop->{deprecated}) {
		$xml .= $indent . '    <property name="' . $pname . '" type="' .
		    $self->to_xml_type($type) . '" access="' . $access . '">' . "\n";
		$xml .= $indent . '      <annotation name="org.freedesktop.DBus.Deprecated" value="true"/>' . "\n";
		$xml .= $indent . '    </property>' . "\n";
	    } else {
		$xml .= $indent . '    <property name="' . $pname . '" type="' .
		    $self->to_xml_type($type) . '" access="' . $access . '"/>' . "\n";
	    }
	}

	$xml .= $indent . '  </interface>' . "\n";
    }

    #
    # Interfaces don't have children,  objects do
    #
    if ($obj) {
	foreach ( $obj->_get_sub_nodes ) {
	    $xml .= $indent . '  <node name="' . $_ . '"/>' . "\n";
	}
    } else {
	foreach my $child (@{$self->{children}}) {
	    if (ref($child) eq __PACKAGE__) {
		$xml .= $child->to_xml($indent . "  ");
	    } else {
		$xml .= $indent . '  <node name="' . $child . '"/>' . "\n";
	    }
	}
    }

    $xml .= $indent . "</node>\n";
}

=item $type = $ins->to_xml_type($type)

Takes a text-based representation of a data type and returns
the compact representation used in XML introspection data.

=cut

sub to_xml_type {
    my $self = shift;
    my $type = shift;

    my $sig = '';
    if (ref($type) eq "ARRAY") {
	if ($type->[0] eq "array") {
	    if ($#{$type} != 1) {
		die "array spec must contain only 1 type";
	    }
	    $sig .= chr($compound_type_map{$type->[0]});
	    $sig .= $self->to_xml_type($type->[1]);
	} elsif ($type->[0] eq "struct") {
	    $sig .= "(";
	    for (my $i = 1 ; $i <= $#{$type} ; $i++) {
		$sig .= $self->to_xml_type($type->[$i]);
	    }
	    $sig .= ")";
	} elsif ($type->[0] eq "dict") {
	    if ($#{$type} != 2) {
		die "dict spec must contain only 2 types";
	    }
	    $sig .= chr($compound_type_map{"array"});
	    $sig .= "{";
	    $sig .= $self->to_xml_type($type->[1]);
	    $sig .= $self->to_xml_type($type->[2]);
	    $sig .= "}";
	} elsif ($type->[0] eq "variant") {
	    if ($#{$type} != 0) {
		die "dict spec must contain no sub-types";
	    }
	    $sig .= chr($compound_type_map{"variant"});
	} else {
	    die "unknown/unsupported compound type " . $type->[0] . " expecting 'array', 'struct', or 'dict'";
	}
    } else {
	die "unknown/unsupported scalar type '$type'"
	    unless exists $simple_type_map{$type};
	$sig .= chr($simple_type_map{$type});
    }
    return $sig;
}

=item $ins->encode($message, $type, $name, $direction, @args)

Append a set of values <@args> to a message object C<$message>.
The C<$type> parameter is either C<signal> or C<method> and
C<$direction> is either C<params> or C<returns>. The introspection
data will be queried to obtain the declared data types & the
argument marshalling accordingly.

=cut

sub encode {
    my $self = shift;
    my $message = shift;
    my $type = shift;
    my $name = shift;
    my $direction = shift;
    my @args = @_;

    my $interface = $message->get_interface;

    my @types;
    if ($interface) {
	if (exists $self->{interfaces}->{$interface}) {
	    if (exists $self->{interfaces}->{$interface}->{$type}->{$name}) {
		@types = @{$self->{interfaces}->{$interface}->{$type}->{$name}->{$direction}};
	    } else {
		warn "missing introspection data when encoding $type '$name' in object " .
		    $self->get_object_path . "\n" if $debug;
	    }
	} else {
	    warn "missing interface '$interface' in introspection data for object '" .
		$self->get_object_path . "' encoding $type '$name'\n" if $debug;
	}
    } else {
	foreach my $in (keys %{$self->{interfaces}}) {
	    if (exists $self->{interfaces}->{$in}->{$type}->{$name}) {
		$interface = $in;
	    }
	}
	if ($interface) {
	    @types = @{$self->{interfaces}->{$interface}->{$type}->{$name}->{$direction}};
	} else {
	    warn "no interface in introspection data for object " .
		$self->get_object_path . " encoding $type '$name'\n" if $debug;
	}
    }

    # If you don't explicitly 'return ()' from methods, Perl
    # will always return a single element representing the
    # return value of the last command executed in the method.
    # To avoid this causing a PITA for methods exported with
    # no return values, we throw away returns instead of dieing
    if ($direction eq "returns" &&
	$#types == -1 &&
	$#args != -1) {
	@args = ();
    }

    # No introspection data available, then just fallback
    # to a plain (guess types) append
    unless (@types) {
	$message->append_args_list(@args);
	return;
    }


    die "expected " . int(@types) . " $direction, but got " . int(@args)
	unless $#types == $#args;

    my $iter = $message->iterator(1);
    foreach my $t ($self->_convert(@types)) {
	$iter->append(shift @args, $t);
    }
}

sub _convert {
    my $self = shift;
    my @in = @_;

    my @out;
    foreach my $in (@in) {
	if (ref($in) eq "ARRAY") {
	    my @subtype = @{$in};
	    shift @subtype;
	    my @subout = $self->_convert(@subtype);
	    die "unknown compound type " . $in->[0] unless
		exists $compound_type_map{lc $in->[0]};

	    push @out, [$compound_type_map{lc $in->[0]}, \@subout];
	} elsif (exists $magic_type_map{lc $in}) {
	    push @out, $magic_type_map{lc $in};
	} else {
	    die "unknown simple type " . $in unless
		exists $simple_type_map{lc $in};
	    push @out, $simple_type_map{lc $in};
	}
    }
    return @out;
}

=item my @args = $ins->decode($message, $type, $name, $direction)

Unmarshalls the contents of a message object C<$message>.
The C<$type> parameter is either C<signal> or C<method> and
C<$direction> is either C<params> or C<returns>. The introspection
data will be queried to obtain the declared data types & the
arguments unmarshalled accordingly.

=cut

sub decode {
    my $self = shift;
    my $message = shift;
    my $type = shift;
    my $name = shift;
    my $direction = shift;

    my $interface = $message->get_interface;

    my @types;
    if ($interface) {
	if (exists $self->{interfaces}->{$interface}) {
	    if (exists $self->{interfaces}->{$interface}->{$type}->{$name}) {
	        @types =
		    @{$self->{interfaces}->{$interface}->{$type}->{$name}->{$direction}};
	    } else {
		warn "missing introspection data when decoding $type '$name' in object " .
		    $self->get_object_path . "\n" if $debug;
	    }
	} else {
	    warn "missing interface '$interface' in introspection data for object '" .
		$self->get_object_path . "' when decoding $type '$name'\n" if $debug;
	}
    } else {
	foreach my $in (keys %{$self->{interfaces}}) {
	    if (exists $self->{interfaces}->{$in}->{$type}->{$name}) {
		$interface = $in;
	    }
	}
	if (!$interface) {
	    warn "no interface in introspection data for object " .
		$self->get_object_path . " decoding $type '$name'\n" if $debug;
	} else {
	    @types =
		@{$self->{interfaces}->{$interface}->{$type}->{$name}->{$direction}};
	}
    }

    # If there are no types defined, just return the
    # actual data from the message, assuming the introspection
    # data was partial.
    return $message->get_args_list
	unless @types;

    my $iter = $message->iterator;

    my $hasnext = $iter->get_arg_type() != &Net::DBus::Binding::Message::TYPE_INVALID;
    my @rawtypes = $self->_convert(@types);
    my @ret;
    while (@types) {
	my $type = shift @types;
	my $rawtype = shift @rawtypes;

	if (exists $magic_type_map{$type}) {
	    push @ret, &$rawtype($message);
	} elsif ($hasnext) {
	    push @ret, $iter->get($rawtype);
	    $hasnext = $iter->next;
	}
    }
    while ($hasnext) {
	push @ret, $iter->get();
	$hasnext = $iter->next;
    }
    return @ret;
}

1;

=pod

=back

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2004-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Exporter>, L<Net::DBus::Binding::Message>

=cut
