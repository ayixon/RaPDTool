



pip check
IF %ERRORLEVEL% NEQ 0 exit /B 1
python -m OpenSSL.debug
IF %ERRORLEVEL% NEQ 0 exit /B 1
exit /B 0
