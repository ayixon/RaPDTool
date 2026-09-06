setlocal EnableDelayedExpansion

cd test

:: Compile example that links gsl
echo "%PREFIX%\Library\include\gsl\gsl_types.h header during test"
type "%PREFIX%\Library\include\gsl\gsl_types.h"

:: Compile example that links gsl
cl.exe /I%PREFIX%\Library\include\gsl gsl.lib regression_test.c
if errorlevel 1 exit 1

:: Run test
.\regression_test.exe
if errorlevel 1 exit 1
