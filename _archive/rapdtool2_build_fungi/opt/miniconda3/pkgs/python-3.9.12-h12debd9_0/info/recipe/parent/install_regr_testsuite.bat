#!/usr/bin/env bash

pushd %SRC_DIR%\test.backup\
dir /s /q
xcopy * %PREFIX%\Lib\
