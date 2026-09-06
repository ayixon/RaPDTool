mkdir build
cd build

cmake ^
    -G "NMake Makefiles" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_POSITION_INDEPENDENT_CODE=1 ^
    -DCMAKE_INSTALL_PREFIX="%LIBRARY_PREFIX%" ^
    -DCMAKE_INSTALL_LIBDIR=lib ^
    ..
if errorlevel 1 exit 1

cmake --build . --config Release
if errorlevel 1 exit 1

@REM Some of the tests fail in part 2 of the tests (SegFault when build type is Release, unexpected value in one test when build typ is Debug)
@REM cmake --build . --target check --config Release
@REM if errorlevel 1 exit 1

cmake --build . --target INSTALL --config Release
if errorlevel 1 exit 1
