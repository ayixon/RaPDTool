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

Net::DBus::Error - Error details for remote method invocation

=head1 SYNOPSIS

  package Music::Player::UnknownFormat;

  use base qw(Net::DBus::Error);

  # Define an error type for unknown track encoding type
  # for a music player service
  sub new {
      my $proto = shift;
      my $class = ref($proto) || $proto;
      my $self = $class->SUPER::new(name => "org.example.music.UnknownFormat",
                                    message => "Unknown track encoding format");
  }


  package Music::Player::Engine;

  ...snip...

  # Play either mp3 or ogg music tracks, otherwise
  # thrown an error
  sub play {
      my $self = shift;
      my $url = shift;

      if ($url =~ /\.(mp3|ogg)$/) {
	  ...play the track
      } else {
         die Music::Player::UnknownFormat->new();
      }
  }


=head1 DESCRIPTION

This objects provides for strongly typed error handling. Normally
a service would simply call

  die "some message text"

When returning the error condition to the calling DBus client, the
message is associated with a generic error code or "org.freedesktop.DBus.Failed".
While this suffices for many applications, occasionally it is desirable
to be able to catch and handle specific error conditions. For such
scenarios the service should create subclasses of the C<Net::DBus::Error>
object providing in a custom error name. This error name is then sent back
to the client instead of the genreic "org.freedesktop.DBus.Failed" code.

=head1 METHODS

=over 4

=cut

package Net::DBus::Error;

use strict;
use warnings;


use overload ('""' => 'stringify');

=item my $error = Net::DBus::Error->new(name => $error_name,
                                        message => $description);

Creates a new error object whose name is given by the C<name>
parameter, and long descriptive text is provided by the
C<message> parameter. The C<name> parameter has certain
formatting rules which must be adhered to. It must only contain
the letters 'a'-'Z', '0'-'9', '-', '_' and '.'. There must be
at least two components separated by a '.', For example a valid
name is 'org.example.Music.UnknownFormat'.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{name} = $params{name} ? $params{name} : die "name parameter is required";
    $self->{message} = $params{message} ? $params{message} : die "message parameter is required";

    bless $self, $class;

    return $self;
}

=item $error->name

Returns the DBus error name associated with the object.

=cut

sub name {
    my $self = shift;
    return $self->{name};
}

=item $error->message

Returns the descriptive text/message associated with the
error condition.

=cut

sub message {
    my $self = shift;
    return $self->{message};
}

=item $error->stringify

Formats the error as a string in a manner suitable for
printing out / logging / displaying to the user, etc.

=cut

sub stringify {
    my $self = shift;

    return $self->{name} . ": " . $self->{message} . ($self->{message} =~ /\n$/ ? "" : "\n");
}


1;

=pod

=back

=head1 AUTHOR

Daniel P. Berrange

=head1 COPYRIGHT

Copyright (C) 2005-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Object>

=cut
