#----------------------------------------------------------------
# Generated CMake target import file.
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "Libssh2::libssh2" for configuration ""
set_property(TARGET Libssh2::libssh2 APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(Libssh2::libssh2 PROPERTIES
  IMPORTED_LINK_INTERFACE_LIBRARIES_NOCONFIG ""
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/lib/libssh2.so.1.0.1"
  IMPORTED_SONAME_NOCONFIG "libssh2.so.1"
  )

list(APPEND _IMPORT_CHECK_TARGETS Libssh2::libssh2 )
list(APPEND _IMPORT_CHECK_FILES_FOR_Libssh2::libssh2 "${_IMPORT_PREFIX}/lib/libssh2.so.1.0.1" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
