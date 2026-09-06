REM these are done automatically for openblas by numpy.distutils, but
REM not for our blas libraries
echo %LIBRARY_LIB%\blas.lib > %LIBRARY_LIB%\blas.fobjects
echo %LIBRARY_LIB%\blas.lib > %LIBRARY_LIB%\blas.cobjects
echo %LIBRARY_LIB%\cblas.lib > %LIBRARY_LIB%\cblas.fobjects
echo %LIBRARY_LIB%\cblas.lib > %LIBRARY_LIB%\cblas.cobjects
echo %LIBRARY_LIB%\lapack.lib > %LIBRARY_LIB%\lapack.fobjects
echo %LIBRARY_LIB%\lapack.lib > %LIBRARY_LIB%\lapack.cobjects

REM Use the G77 ABI wrapper everywhere so that the underlying blas implementation
REM can have a G77 ABI (currently only MKL)
set SCIPY_USE_G77_ABI_WRAPPER=1
REM This builds a Fortran file which calls a C function, but numpy.distutils
REM creates an isolated DLL for these fortran functions and therefore it doesn't
REM see these C functions. workaround this by compiling it ourselves and
REM sneaking it with the blas libraries
REM TODO: rewrite wrap_g77_abi.f with iso_c_binding when the compiler supports it
cl.exe scipy\_build_utils\src\wrap_g77_abi_c.c -c /MD
if %ERRORLEVEL% neq 0 exit 1
echo. > scipy\_build_utils\src\wrap_g77_abi_c.c
echo %SRC_DIR%\wrap_g77_abi_c.obj >> %LIBRARY_LIB%\lapack.fobjects
echo %SRC_DIR%\wrap_g77_abi_c.obj >> %LIBRARY_LIB%\lapack.cobjects

REM Add a file to load the fortran wrapper libraries in scipy/.libs
del scipy\_distributor_init.py
if %ERRORLEVEL% neq 0 exit 1
copy %RECIPE_DIR%\_distributor_init.py scipy\
if %ERRORLEVEL% neq 0 exit 1

%PYTHON% -m pip install . -vv
if %ERRORLEVEL% neq 0 exit 1

REM make sure these aren't packaged
del %LIBRARY_LIB%\blas.fobjects
del %LIBRARY_LIB%\blas.cobjects
del %LIBRARY_LIB%\cblas.fobjects
del %LIBRARY_LIB%\cblas.cobjects
del %LIBRARY_LIB%\lapack.fobjects
del %LIBRARY_LIB%\lapack.cobjects
