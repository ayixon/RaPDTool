#
# Tcl package index file
#
# Note sqlite*3* init specifically
#
package ifneeded sqlite3 3.34.0 \
    [list load [file join $dir libsqlite3.34.0.so] Sqlite3]
