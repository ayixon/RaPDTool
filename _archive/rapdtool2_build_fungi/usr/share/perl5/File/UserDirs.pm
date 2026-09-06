package File::UserDirs;

use strict;
use warnings;
use IPC::System::Simple qw(capturex);
use Exporter 5.57 qw( import );

# ABSTRACT: Find extra media and documents directories
our $VERSION = '0.09'; # VERSION

our %EXPORT_TAGS = (
    all => [
        qw(xdg_desktop_dir xdg_documents_dir xdg_download_dir xdg_music_dir
        xdg_pictures_dir xdg_publicshare_dir xdg_templates_dir xdg_videos_dir)
    ]);
our @EXPORT_OK = @{$EXPORT_TAGS{all}};


sub _xdg_user_dir {
    my ($purpose) = @_;
    my $dir = capturex 'xdg-user-dir', $purpose;
    chomp $dir;
    return $dir;
}

sub xdg_desktop_dir     {return _xdg_user_dir 'DESKTOP';}
sub xdg_documents_dir   {return _xdg_user_dir 'DOCUMENTS';}
sub xdg_download_dir    {return _xdg_user_dir 'DOWNLOAD';}
sub xdg_music_dir       {return _xdg_user_dir 'MUSIC';}
sub xdg_pictures_dir    {return _xdg_user_dir 'PICTURES';}
sub xdg_publicshare_dir {return _xdg_user_dir 'PUBLICSHARE';}
sub xdg_templates_dir   {return _xdg_user_dir 'TEMPLATES';}
sub xdg_videos_dir      {return _xdg_user_dir 'VIDEOS';}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

File::UserDirs - Find extra media and documents directories

=head1 VERSION

version 0.09

=head1 SYNOPSIS

 use File::UserDirs qw(:all);
 print xdg_desktop_dir; # e.g. /home/user/Desktop

=head1 DESCRIPTION

This module can be used to find directories as informally specified
by the Freedesktop.org xdg-user-dirs software. This
gives a mechanism to locate extra directories for media and documents files.

=head1 FUNCTIONS

May be exported on request.
Also the group C<:all> is defined which exports all methods.

=head2 xdg_desktop_dir

 my $dir = xdg_desktop_dir;

Returns the desktop directory. Unless changed by the user,
this is the directory F<Desktop> in the home directory.

=head2 xdg_documents_dir

 my $dir = xdg_documents_dir;

Returns the documents directory. Unless changed by the user,
this is the home directory.

=head2 xdg_download_dir

 my $dir = xdg_download_dir;

Returns the download directory. Unless changed by the user,
this is the home directory.

=head2 xdg_music_dir

 my $dir = xdg_music_dir;

Returns the music directory. Unless changed by the user,
this is the home directory.

=head2 xdg_pictures_dir

 my $dir = xdg_pictures_dir;

Returns the pictures directory. Unless changed by the user,
this is the home directory.

=head2 xdg_publicshare_dir

 my $dir = xdg_publicshare_dir;

Returns the public share directory. Unless changed by the user,
this is the home directory.

=head2 xdg_templates_dir

 my $dir = xdg_templates_dir;

Returns the templates directory. Unless changed by the user,
this is the home directory.

=head2 xdg_videos_dir

 my $dir = xdg_videos_dir;

Returns the videos directory. Unless changed by the user,
this is the home directory.

=head1 DIAGNOSTICS

=over

=item C<"xdg-user-dir" failed to start: %s>

The executable C<xdg-user-dir> could not be run, most likely because it was not
installed. See L</"DEPENDENCIES">.

=back

=head1 CONFIGURATION AND ENVIRONMENT

The location of the directories can be specified by the user in the file
F<$XDG_CONFIG_HOME/user-dirs.dirs>. It is a shell file setting a number of
environment variables. To find the exact pathname from Perl, run:

 use File::BaseDir qw(config_home);
 print config_home('user-dirs.dirs');

=head2 Example customised F<user-dirs.dirs>

 XDG_DESKTOP_DIR="$HOME/Workspace"
 XDG_DOCUMENTS_DIR="$HOME/Files"
 XDG_DOWNLOAD_DIR="$HOME/Files/Downloads"
 XDG_MUSIC_DIR="$HOME/Files/Audio"
 XDG_PICTURES_DIR="$HOME/Files/Images"
 XDG_PUBLICSHARE_DIR="$HOME/public_html"
 XDG_TEMPLATES_DIR="$HOME/Files/Document templates"
 XDG_VIDEOS_DIR="$HOME/Files/Video"

=head1 DEPENDENCIES

This module requires the executable F<xdg-user-dir> from the package
C<xdg-user-dirs>. Source code is available from
L<http://cgit.freedesktop.org/xdg/xdg-user-dirs/>.

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
