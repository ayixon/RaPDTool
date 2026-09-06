set CMAKE_DBG=trace --debug-find --debug-output --debug-trycompile
set CMAKE_DBG=--debug-find
cmake -G"%CMAKE_GENERATOR%" -DPY_VER=%1 %CMAKE_DBG% .
if %ErrorLevel% neq 0 exit /b 1
cmake --build . --config Release
if %ErrorLevel% neq 0 exit /b 1
