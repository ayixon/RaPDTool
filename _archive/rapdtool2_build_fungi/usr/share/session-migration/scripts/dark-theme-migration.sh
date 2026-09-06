#!/bin/sh

# If the theme is "-dark", set the GNOME 42 dark preference
case $(gsettings get org.gnome.desktop.interface gtk-theme) in
  *-dark\')
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    ;;
esac

# And set the new high-contrast preference
case $(gsettings get org.gnome.desktop.interface gtk-theme) in
  \'*HighContrast*)
    gsettings set org.gnome.desktop.a11y.interface high-contrast true
    ;;
esac
