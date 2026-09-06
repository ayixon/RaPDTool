# https://martinopilia.com/posts/2018/09/15/building-python-extension.html
cmake_minimum_required(VERSION 3.18)
enable_language(C)
project(mymath)

option(PY_VER, "Python version to use")

# Deprecated.
# See https://cmake.org/cmake/help/latest/module/FindPython.html#module:FindPython
# find_package(PythonInterp ${PY_VER} REQUIRED
#              PATHS $ENV{CONDA_PREFIX})
#  This goes after, since it uses PythonInterp as hint
# find_library(PythonLibs ${PY_VER} REQUIRED)

find_package(Python3 ${PY_VER} EXACT MODULE REQUIRED
             COMPONENTS Interpreter Development.Module)
