package File::IconTheme;

use strict;
use warnings;
use File::BaseDir qw(data_dirs);
use File::Spec;
use Exporter 5.57 qw( import );

# ABSTRACT: Find icon directories
our $VERSION = '0.09'; # VERSION

our @EXPORT_OK = qw(xdg_icon_theme_search_dirs);

sub xdg_icon_theme_search_dirs {

    return grep {-d $_ && -r $_}
        File::Spec->catfile(File::BaseDir->_home, '.icons'),
        data_dirs('icons'),
        '/usr/share/pixmaps';
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

File::IconTheme - Find icon directories

=head1 VERSION

version 0.09

=head1 SYNOPSIS

 use File::IconTheme qw(xdg_icon_theme_search_dirs);
 print join "\n", xdg_icon_theme_search_dirs;

=head1 DESCRIPTION

This module can be used to find directories as specified
by the Freedesktop.org Icon Theme Specification. Currently only a tiny
(but most useful) part of the specification is implemented.

In case you want to B<store> an icon theme, use the directory returned by:

 use File::BaseDir qw(data_dirs);
 print scalar data_dirs('icons');

=head1 FUNCTIONS

Can be exported on request.

=head2 xdg_icon_theme_search_dirs

 my @dirs = xdg_icon_theme_search_dir;

Returns a list of the base directories of icon themes.

=head1 CONFIGURATION AND ENVIRONMENT

C<$XDG_DATA_HOME>, C<$XDG_DATA_DIRS>

=head1 SEE ALSO

L<http://standards.freedesktop.org/icon-theme-spec/>

=head1 AUTHORS

=over 4

=item *

Jaap Karssenberg || Pardus [Larus] <pardus@cpan.org>

=item *

Graham Ollis <plicease@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2003-2021 by Jaap Karssenberg || Pardus [Larus] <pardus@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
