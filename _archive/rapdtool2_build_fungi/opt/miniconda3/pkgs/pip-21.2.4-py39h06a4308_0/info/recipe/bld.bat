if "%PY_INTERP_DEBUG%" neq "" (
  %PYTHON% setup.py build -g install --single-version-externally-managed --record record.txt -v -v
  if errorlevel 1 exit 1
) else (
  %PYTHON% setup.py build install --single-version-externally-managed --record record.txt -v -v
  if errorlevel 1 exit 1
)

cd %SCRIPTS%
del *.exe
del *.exe.manifest
del pip2*
del pip3*
