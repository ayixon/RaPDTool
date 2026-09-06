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

Net::DBus::Test::MockIterator - Iterator over a mock message

=head1 SYNOPSIS

Creating a new message

  my $msg = new Net::DBus::Test::MockMessage
  my $iterator = $msg->iterator;

  $iterator->append_boolean(1);
  $iterator->append_byte(123);


Reading from a message

  my $msg = ...get it from somewhere...
  my $iter = $msg->iterator();

  my $i = 0;
  while ($iter->has_next()) {
    $iter->next();
    $i++;
    if ($i == 1) {
       my $val = $iter->get_boolean();
    } elsif ($i == 2) {
       my $val = $iter->get_byte();
    }
  }

=head1 DESCRIPTION

This module provides a "mock" counterpart to the L<Net::DBus::Binding::Iterator>
object which is capable of iterating over mock message objects. Instances of this
module are not created directly, instead they are obtained via the C<iterator>
method on the L<Net::DBus::Test::MockMessage> module.

=head1 METHODS

=over 4

=cut

package Net::DBus::Test::MockIterator;


use 5.006;
use strict;
use warnings;

sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{data} = exists $params{data} ? $params{data} : die "data parameter is required";
    $self->{append} = exists $params{append} ? $params{append} : 0;
    $self->{position} = 0;

    bless $self, $class;

    return $self;
}

=item $res = $iter->has_next()

Determines if there are any more fields in the message
itertor to be read. Returns a positive value if there
are more fields, zero otherwise.

=cut

sub has_next {
    my $self = shift;

    if ($self->{position} < $#{$self->{data}}) {
	return 1;
    }
    return 0;
}


=item $success = $iter->next()

Skips the iterator onto the next field in the message.
Returns a positive value if the current field pointer
was successfully advanced, zero otherwise.

=cut

sub next {
    my $self = shift;

    $self->{position}++;
    if ($self->{position} <= $#{$self->{data}}) {
	return 1;
    }
    return 0;
}

=item my $val = $iter->get_boolean()

=item $iter->append_boolean($val);

Read or write a boolean value from/to the
message iterator

=cut

sub get_boolean {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_BOOLEAN);
}

sub append_boolean {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_BOOLEAN, $_[0] ? 1 : "");
}

=item my $val = $iter->get_byte()

=item $iter->append_byte($val);

Read or write a single byte value from/to the
message iterator.

=cut

sub get_byte {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_BYTE);
}

sub append_byte {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_BYTE, $_[0]);
}


=item my $val = $iter->get_string()

=item $iter->append_string($val);

Read or write a UTF-8 string value from/to the
message iterator


=cut

sub get_string {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_STRING);
}

sub append_string {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_STRING, $_[0]);
}

=item my $val = $iter->get_object_path()

=item $iter->append_object_path($val);

Read or write a UTF-8 string value, whose contents is
a valid object path, from/to the message iterator


=cut

sub get_object_path {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_OBJECT_PATH);
}

sub append_object_path {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_OBJECT_PATH, $_[0]);
}

=item my $val = $iter->get_signature()

=item $iter->append_signature($val);

Read or write a UTF-8 string, whose contents is a
valid type signature, value from/to the message iterator


=cut

sub get_signature {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_SIGNATURE);
}

sub append_signature {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_SIGNATURE, $_[0]);
}

=item my $val = $iter->get_int16()

=item $iter->append_int16($val);

Read or write a signed 16 bit value from/to the
message iterator


=cut

sub get_int16 {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_INT16);
}

sub append_int16 {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_INT16, int($_[0]));
}

=item my $val = $iter->get_uint16()

=item $iter->append_uint16($val);

Read or write an unsigned 16 bit value from/to the
message iterator


=cut

sub get_uint16 {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_UINT16);
}

sub append_uint16 {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_UINT16, int($_[0]));
}

=item my $val = $iter->get_int32()

=item $iter->append_int32($val);

Read or write a signed 32 bit value from/to the
message iterator


=cut

sub get_int32 {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_INT32);
}

sub append_int32 {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_INT32, int($_[0]));
}

=item my $val = $iter->get_uint32()

=item $iter->append_uint32($val);

Read or write an unsigned 32 bit value from/to the
message iterator


=cut

sub get_uint32 {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_UINT32);
}

sub append_uint32 {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_UINT32, int($_[0]));
}

=item my $val = $iter->get_int64()

=item $iter->append_int64($val);

Read or write a signed 64 bit value from/to the
message iterator. An error will be raised if this
build of Perl does not support 64 bit integers


=cut

sub get_int64 {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_INT64);
}

sub append_int64 {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_INT64, int($_[0]));
}

=item my $val = $iter->get_uint64()

=item $iter->append_uint64($val);

Read or write an unsigned 64 bit value from/to the
message iterator. An error will be raised if this
build of Perl does not support 64 bit integers


=cut

sub get_uint64 {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_UINT64);
}

sub append_uint64 {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_UINT64, int($_[0]));
}

=item my $val = $iter->get_double()

=item $iter->append_double($val);

Read or write a double precision floating point value
from/to the message iterator

=cut

sub get_double {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_DOUBLE);
}

sub append_double {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_DOUBLE, $_[0]);
}


=item my $val = $iter->get_unix_fd()

=item $iter->append_unix_fd($val);

Read or write a unix_fd value from/to the
message iterator

=cut

sub get_unix_fd {
    my $self = shift;
    return $self->_get(&Net::DBus::Binding::Message::TYPE_UNIX_FD);
}

sub append_unix_fd {
    my $self = shift;
    $self->_append(&Net::DBus::Binding::Message::TYPE_UNIX_FD, $_[0] ? 1 : "");
}


=item my $value = $iter->get()

=item my $value = $iter->get($type);

Get the current value pointed to by this iterator. If the optional
C<$type> parameter is supplied, the wire type will be compared with
the desired type & a warning output if their differ. The C<$type>
value must be one of the C<Net::DBus::Binding::Message::TYPE*>
constants.

=cut

sub get {
    my $self = shift;
    my $type = shift;

    if (defined $type) {
	if (ref($type)) {
	    if (ref($type) eq "ARRAY") {
		# XXX we should recursively validate types
		$type = $type->[0];
		if ($type eq &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
		    $type = &Net::DBus::Binding::Message::TYPE_ARRAY;
		}
	    } else {
		die "unsupport type reference $type";
	    }
	}

	my $actual = $self->get_arg_type;
	if ($actual != $type) {
	    # "Be strict in what you send, be leniant in what you accept"
	    #    - ie can't rely on python to send correct types, eg int32 vs uint32
	    #die "requested type '" . chr($type) . "' ($type) did not match wire type '" . chr($actual) . "' ($actual)";
	    warn "requested type '" . chr($type) . "' ($type) did not match wire type '" . chr($actual) . "' ($actual)";
	    $type = $actual;
	}
    } else {
	$type = $self->get_arg_type;
    }

    if ($type == &Net::DBus::Binding::Message::TYPE_STRING) {
	return $self->get_string;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_BOOLEAN) {
	return $self->get_boolean;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_BYTE) {
	return $self->get_byte;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_INT16) {
	return $self->get_int16;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT16) {
	return $self->get_uint16;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_INT32) {
	return $self->get_int32;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT32) {
	return $self->get_uint32;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_INT64) {
	return $self->get_int64;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT64) {
	return $self->get_uint64;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_DOUBLE) {
	return $self->get_double;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_ARRAY) {
	my $array_type = $self->get_element_type();
	if ($array_type == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
	    return $self->get_dict();
	} else {
	    return $self->get_array($array_type);
	}
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_STRUCT) {
	return $self->get_struct();
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_VARIANT) {
	return $self->get_variant();
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
	die "dictionary can only occur as part of an array type";
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_INVALID) {
	die "cannot handle Net::DBus::Binding::Message::TYPE_INVALID";
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_OBJECT_PATH) {
	return $self->get_object_path();
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_SIGNATURE) {
	return $self->get_signature();
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_UNIX_FD) {
	return $self->get_unix_fd;
    } else {
	die "unknown argument type '" . chr($type) . "' ($type)";
    }
}

=item my $hashref = $iter->get_dict()

If the iterator currently points to a dictionary value, unmarshalls
and returns the value as a hash reference.

=cut

sub get_dict {
    my $self = shift;

    my $iter = $self->_recurse();
    my $type = $iter->get_arg_type();
    my $dict = {};
    while ($type == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
	my $entry = $iter->get_struct();
	if ($#{$entry} != 1) {
	    die "Dictionary entries must be structs of 2 elements. This entry has " . ($#{$entry}+1) ." elements";
	}
	
	$dict->{$entry->[0]} = $entry->[1];
	$iter->next();
	$type = $iter->get_arg_type();
    }
    return $dict;
}

=item my $hashref = $iter->get_array()

If the iterator currently points to an array value, unmarshalls
and returns the value as a array reference.

=cut

sub get_array {
    my $self = shift;
    my $array_type = shift;

    my $iter = $self->_recurse();
    my $type = $iter->get_arg_type();
    my $array = [];
    while ($type != &Net::DBus::Binding::Message::TYPE_INVALID) {
	if ($type != $array_type) {
	    die "Element $type not of array type $array_type";
	}

	my $value = $iter->get($type);
	push @{$array}, $value;
	$iter->next();
	$type = $iter->get_arg_type();
    }
    return $array;
}

=item my $hashref = $iter->get_variant()

If the iterator currently points to a variant value, unmarshalls
and returns the value contained in the variant.

=cut

sub get_variant {
    my $self = shift;

    my $iter = $self->_recurse();
    return $iter->get();
}


=item my $hashref = $iter->get_struct()

If the iterator currently points to an struct value, unmarshalls
and returns the value as a array reference. The values in the array
correspond to members of the struct.

=cut

sub get_struct {
    my $self = shift;

    my $iter = $self->_recurse();
    my $type = $iter->get_arg_type();
    my $struct = [];
    while ($type != &Net::DBus::Binding::Message::TYPE_INVALID) {
	my $value = $iter->get($type);
	push @{$struct}, $value;
	$iter->next();
	$type = $iter->get_arg_type();
    }
    return $struct;
}

=item $iter->append($value)

=item $iter->append($value, $type)

Appends a value to the message associated with this iterator. The
value is marshalled into wire format, according to the following
rules.

If the C<$value> is an instance of L<Net::DBus::Binding::Value>,
the embedded data type is used.

If the C<$type> parameter is supplied, that is taken to represent
the data type. The type must be one of the C<Net::DBus::Binding::Message::TYPE_*>
constants.

Otherwise, the data type is chosen to be a string, dict or array
according to the perl data types SCALAR, HASH or ARRAY.

=cut

sub append {
    my $self = shift;
    my $value = shift;
    my $type = shift;

    if (ref($value) eq "Net::DBus::Binding::Value" &&
        ((! defined ref($type)) ||
	 (ref($type) ne "ARRAY") ||
	 $type->[0] != &Net::DBus::Binding::Message::TYPE_VARIANT)) {
	$type = $value->type;
	$value = $value->value;
    }

    if (!defined $type) {
	$type = $self->guess_type($value);
    }

    if (ref($type) eq "ARRAY") {
	my $maintype = $type->[0];
	my $subtype = $type->[1];

	if ($maintype == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
	    $self->append_dict($value, $subtype);
	} elsif ($maintype == &Net::DBus::Binding::Message::TYPE_STRUCT) {
	    $self->append_struct($value, $subtype);
	} elsif ($maintype == &Net::DBus::Binding::Message::TYPE_ARRAY) {
	    $self->append_array($value, $subtype);
	} elsif ($maintype == &Net::DBus::Binding::Message::TYPE_VARIANT) {
	    $self->append_variant($value, $subtype);
	} else {
	    die "Unsupported compound type ", $maintype, " ('", chr($maintype), "')";
	}
    } else {
	# XXX is this good idea or not
	$value = '' unless defined $value;

	if ($type == &Net::DBus::Binding::Message::TYPE_BOOLEAN) {
	    $self->append_boolean($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_BYTE) {
	    $self->append_byte($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_STRING) {
	    $self->append_string($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_INT16) {
	    $self->append_int16($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT16) {
	    $self->append_uint16($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_INT32) {
	    $self->append_int32($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT32) {
	    $self->append_uint32($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_INT64) {
	    $self->append_int64($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT64) {
	    $self->append_uint64($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_DOUBLE) {
	    $self->append_double($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_OBJECT_PATH) {
	    $self->append_object_path($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_SIGNATURE) {
	    $self->append_signature($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_UNIX_FD) {
	    $self->append_unix_fd($value);
	} else {
	    die "Unsupported scalar type ", $type, " ('", chr($type), "')";
	}
    }
}


=item my $type = $iter->guess_type($value)

Make a best guess at the on the wire data type to use for
marshalling C<$value>. If the value is a hash reference,
the dictionary type is returned; if the value is an array
reference the array type is returned; otherwise the string
type is returned.

=cut

sub guess_type {
    my $self = shift;
    my $value = shift;

    if (ref($value)) {
	if (UNIVERSAL::isa($value, "Net::DBus::Binding::Value")) {
	    my $type = $value->type;
	    if (ref($type) && ref($type) eq "ARRAY") {
		my $maintype = $type->[0];
		my $subtype = $type->[1];

		if (!defined $subtype) {
		    if ($maintype == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
			$subtype = [ $self->guess_type(($value->value())[0]->[0]),
				     $self->guess_type(($value->value())[0]->[1]) ];
		    } elsif ($maintype == &Net::DBus::Binding::Message::TYPE_ARRAY) {
			$subtype = [ $self->guess_type(($value->value())[0]->[0]) ];
		    } elsif ($maintype == &Net::DBus::Binding::Message::TYPE_STRUCT) {
			$subtype = [ map { $self->guess_type($_) } @{($value->value())[0]} ];
		    } elsif ($maintype == &Net::DBus::Binding::Message::TYPE_VARIANT) {
			$subtype = $self->guess_type($value->value);
		    } else {
			die "Unguessable compound type '$maintype' ('", chr($maintype), "')\n";
		    }
		}
		return [$maintype, $subtype];
	    } else {
		return $type;
	    }
	} elsif (ref($value) eq "HASH") {
	    my $key = (keys %{$value})[0];
	    my $val = $value->{$key};
	    # XXX Basically impossible to decide between DICT & STRUCT
	    return [ &Net::DBus::Binding::Message::TYPE_DICT_ENTRY,
		     [ &Net::DBus::Binding::Message::TYPE_STRING, $self->guess_type($val)] ];
	} elsif (ref($value) eq "ARRAY") {
	    return [ &Net::DBus::Binding::Message::TYPE_ARRAY,
		     [$self->guess_type($value->[0])] ];
	} else {
	    die "cannot marshall reference of type " . ref($value);
	}
    } else {
	# XXX Should we bother trying to guess integer & floating point types ?
	# I say sod it, because strongly typed languages will support introspection
	# and loosely typed languages won't care about the difference
	return &Net::DBus::Binding::Message::TYPE_STRING;
    }
}

=item my $sig = $iter->format_signature($type)

Given a data type representation, construct a corresponding
signature string

=cut

sub format_signature {
    my $self = shift;
    my $type = shift;
    my ($sig, $t, $i);

    $sig = "";
    $i = 0;

    if (ref($type) eq "ARRAY") {
	while ($i <= $#{$type}) {
	    $t = $$type[$i];
	
	    if (ref($t) eq "ARRAY") {
		$sig .= $self->format_signature($t);
	    } elsif ($t == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
		$sig .= chr (&Net::DBus::Binding::Message::TYPE_ARRAY);
		$sig .= "{" . $self->format_signature($$type[++$i]) . "}";
	    } elsif ($t == &Net::DBus::Binding::Message::TYPE_STRUCT) {
		$sig .= "(" . $self->format_signature($$type[++$i]) . ")";
	    } else {
		$sig .= chr($t);
	    }
	
	    $i++;
	}
    } else {
	$sig .= chr ($type);
    }

    return $sig;
}

=item $iter->append_array($value, $type)

Append an array of values to the message. The C<$value> parameter
must be an array reference, whose elements all have the same data
type specified by the C<$type> parameter.

=cut

sub append_array {
    my $self = shift;
    my $array = shift;
    my $type = shift;

    if (!defined($type)) {
	$type = [$self->guess_type($array->[0])];
    }

    die "array must only have one type"
	if $#{$type} > 0;

    my $sig = $self->format_signature($type);
    my $iter = $self->_open_container(&Net::DBus::Binding::Message::TYPE_ARRAY, $sig);

    foreach my $value (@{$array}) {
	$iter->append($value, $type->[0]);
    }
}


=item $iter->append_struct($value, $type)

Append a struct to the message. The C<$value> parameter
must be an array reference, whose elements correspond to
members of the structure. The C<$type> parameter encodes
the type of each member of the struct.

=cut

sub append_struct {
    my $self = shift;
    my $struct = shift;
    my $type = shift;

    if (defined($type) &&
	$#{$struct} != $#{$type}) {
	die "number of values does not match type";
    }

    my $iter = $self->_open_container(&Net::DBus::Binding::Message::TYPE_STRUCT, "");

    my @type = defined $type ? @{$type} : ();
    foreach my $value (@{$struct}) {
	$iter->append($value, shift @type);
    }
}

=item $iter->append_dict($value, $type)

Append a dictionary to the message. The C<$value> parameter
must be an hash reference.The C<$type> parameter encodes
the type of the key and value of the hash.

=cut

sub append_dict {
    my $self = shift;
    my $hash = shift;
    my $type = shift;

    my $sig;

    $sig  = "{";
    $sig .= $self->format_signature($type);
    $sig .= "}";

    my $iter = $self->_open_container(&Net::DBus::Binding::Message::TYPE_ARRAY, $sig);

    foreach my $key (keys %{$hash}) {
	my $value = $hash->{$key};
	my $entry = $iter->_open_container(&Net::DBus::Binding::Message::TYPE_DICT_ENTRY, $sig);

	$entry->append($key, $type->[0]);
	$entry->append($value, $type->[1]);
    }
}

=item $iter->append_variant($value)

Append a value to the message, encoded as a variant type. The
C<$value> can be of any type, however, the variant will be
encoded as either a string, dictionary or array according to
the rules of the C<guess_type> method.

=cut

sub append_variant {
    my $self = shift;
    my $value = shift;
    my $type = shift;

    if (UNIVERSAL::isa($value, "Net::DBus::Binding::Value")) {
	$type = [$self->guess_type($value)];
	$value = $value->value;
    } elsif (!defined $type || !defined $type->[0]) {
	$type = [$self->guess_type($value)];
    }
    die "variant must only have one type"
	if defined $type && $#{$type} > 0;

    my $sig = $self->format_signature($type->[0]);
    my $iter = $self->_open_container(&Net::DBus::Binding::Message::TYPE_VARIANT, $sig);
    $iter->append($value, $type->[0]);
}


=item my $type = $iter->get_arg_type

Retrieves the type code of the value pointing to by this iterator.
The returned code will correspond to one of the constants
C<Net::DBus::Binding::Message::TYPE_*>

=cut

sub get_arg_type {
    my $self = shift;

    return &Net::DBus::Binding::Message::TYPE_INVALID
	if $self->{position} > $#{$self->{data}};

    my $data = $self->{data}->[$self->{position}];
    return $data->[0];
}

=item my $type = $iter->get_element_type

If the iterator points to an array, retrieves the type code of
array elements. The returned code will correspond to one of the
constants C<Net::DBus::Binding::Message::TYPE_*>

=cut

sub get_element_type {
    my $self = shift;

    die "current element is not valid" if $self->{position} > $#{$self->{data}};

    my $data = $self->{data}->[$self->{position}];
    if ($data->[0] != &Net::DBus::Binding::Message::TYPE_ARRAY) {
	die "current element is not an array";
    }
    return $data->[1]->[0]->[0];
}



sub _recurse {
    my $self = shift;

    die "_recurse call is not valid for writable iterator" if $self->{append};

    die "current element is not valid" if $self->{position} > $#{$self->{data}};

    my $data = $self->{data}->[$self->{position}];

    my $type = $data->[0];
    if ($type != &Net::DBus::Binding::Message::TYPE_STRUCT &&
	$type != &Net::DBus::Binding::Message::TYPE_ARRAY &&
	$type != &Net::DBus::Binding::Message::TYPE_DICT_ENTRY &&
	$type != &Net::DBus::Binding::Message::TYPE_VARIANT) {
	die "current data element '$type' is not a container";
    }

    return $self->_new(data => $data->[1],
		       append => 0);
}


sub _append {
    my $self = shift;
    my $type = shift;
    my $data = shift;

    die "iterator is not open for append" unless $self->{append};

    push @{$self->{data}}, [$type, $data];
}


sub _open_container {
    my $self = shift;
    my $type = shift;
    my $sig = shift;

    my $data = [];

    push @{$self->{data}}, [$type, $data, $sig];

    return $self->_new(data => $data,
		       append => 1);
}



sub _get {
    my $self = shift;
    my $type = shift;

    die "iterator is not open for reading" if $self->{append};

    die "current element is not valid" if $self->{position} > $#{$self->{data}};

    my $data = $self->{data}->[$self->{position}];

    die "data type does not match" unless $data->[0] == $type;

    return $data->[1];
}

1;

=pod

=back

=head1 BUGS

It doesn't completely replicate the API of L<Net::DBus::Binding::Iterator>,
merely enough to make the high level bindings work in a test scenario.

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2005-2009 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Test::MockMessage>, L<Net::DBus::Binding::Iterator>,
L<http://www.mockobjects.com/Faq.html>

=cut
