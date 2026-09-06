



pytest -v tests
IF %ERRORLEVEL% NEQ 0 exit /B 1
conda-content-trust --help
IF %ERRORLEVEL% NEQ 0 exit /B 1
exit /B 0
