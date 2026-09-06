#!/bin/bash

# Use the G77 ABI wrapper everywhere so that the underlying blas implementation
# can have a G77 ABI (currently only MKL)
export SCIPY_USE_G77_ABI_WRAPPER=1

if [[ "$python_impl" == "pypy" && "$target_platform" == "linux-ppc64le" ]]; then
    $PYTHON setup.py install --single-version-externally-managed --record=record.txt
else
    $PYTHON -m pip install . -vv
fi
