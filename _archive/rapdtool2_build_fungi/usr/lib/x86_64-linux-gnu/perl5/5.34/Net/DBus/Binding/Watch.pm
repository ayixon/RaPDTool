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

Net::DBus::Binding::Watch - binding to the dbus watch API

=cut

package Net::DBus::Binding::Watch;

use 5.006;
use strict;
use warnings;

use Net::DBus;

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;

    die "&Net::DBus::Binding::Watch::constant not defined" if $constname eq '_constant';

    if (!exists $Net::DBus::Binding::Watch::_constants{$constname}) {
        die "no such constant \$Net::DBus::Binding::Watch::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Net::DBus::Binding::Watch::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}

1;

=pod

=head1 AUTHOR

Daniel P. Berrange.

=head1 COPYRIGHT

Copyright (C) 2004-2011 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Binding::Connection>

=cut

