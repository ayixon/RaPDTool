:: Check where we are.
echo %CONDA_PREFIX%
if errorlevel 1 exit 1

:: Check version via import.
python -c "from __future__ import print_function; import conda; print(conda.__version__)"
if errorlevel 1 exit 1

:: Show where the conda commands are.
where conda
if errorlevel 1 exit 1
where conda-env
if errorlevel 1 exit 1

:: Run some conda commands.
conda --version
if errorlevel 1 exit 1
conda info
if errorlevel 1 exit 1
conda env --help
if errorlevel 1 exit 1

if "%run_pytest%"=="yes" pytest tests -m "not integration and not installed" -vv

:: :: Brough from the test.commands section in meta.yaml
:: :: Kept here for reference
:: SET CONDA_SHLVL=
:: CALL %PREFIX%\condabin\conda_hook.bat
:: conda.bat activate base
:: FOR /F "delims=" %%i IN ('python -c "import sys; print(sys.version_info[0])"') DO set "PYTHON_MAJOR_VERSION=%%i"
:: SET TEST_PLATFORM=win
:: FOR /F "delims=" %%i IN ('python -c "import random as r; print(r.randint(0,4294967296))"') DO set "PYTHONHASHSEED=%%i"
:: SET
:: where conda
:: conda info
:: conda create -y -p .\built-conda-test-env
:: conda.bat activate .\built-conda-test-env
:: ECHO %CONDA_PREFIX%
:: IF NOT "%CONDA_PREFIX%"=="%CD%\built-conda-test-env" EXIT /B 1
:: conda.bat deactivate
:: SET MSYSTEM=MINGW%ARCH%
:: SET MSYS2_PATH_TYPE=inherit
:: SET CHERE_INVOKING=1
:: FOR /F "delims=" %%i IN ('cygpath.exe -u "%PREFIX%"') DO set "PREFIXP=%%i"
:: bash -lc "source %PREFIXP%/Scripts/activate"