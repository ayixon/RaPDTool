set PATH=%PREFIX%\cmake-bin\bin;%PATH%

set CFLAGS=
set CXXFLAGS=

mkdir build
pushd build
  cmake .. -G "%CMAKE_GENERATOR%"                     ^
           -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX%  ^
           -DCMAKE_BUILD_TYPE=Release               ^
           -DBUILD_SHARED_LIBS=ON
  cmake --build . --config Release --target INSTALL
popd
