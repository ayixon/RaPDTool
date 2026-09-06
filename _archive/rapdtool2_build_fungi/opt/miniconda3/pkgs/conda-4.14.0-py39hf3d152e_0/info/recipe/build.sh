#!/bin/bash

if [[ "$build_platform" != "$target_platform" && -z "$PYTHONPATH" ]]; then
    # conda-build special cases conda and doesn't activate it
    # See https://github.com/conda/conda-build/blob/1010e8309a20e144c51b1d86b2daebd146be923e/conda_build/metadata.py#L2273
    # I don't know why 'conda' is special cased there, but let's try activate here and deactivate at the end.
    RUN_DEACTIVATE_MANUALLY=1
    export CONDA_PREFIX=$BUILD_PREFIX
    for file in `ls $BUILD_PREFIX/etc/conda/activate.d/*.sh | sort -V`; do
        source $file
    done
fi

echo $PKG_VERSION > conda/.version
$PYTHON setup.py install --single-version-externally-managed --record record.txt
if [[ $(uname -o) != Msys ]]; then
  rm -rf "$SP_DIR/conda/shell/*.exe"
fi
$PYTHON -m conda init --install
if [[ $(uname -o) == Msys ]]; then
  sed -i "s|CONDA_EXE=.*|CONDA_EXE=\'${PREFIXW//\\/\\\\}\\\\Scripts\\\\conda.exe\'|g" $PREFIX/etc/profile.d/conda.sh
fi

if [[ "$RUN_DEACTIVATE_MANUALLY" == 1 ]]; then
     for file in `ls $BUILD_PREFIX/etc/conda/deactivate.d/*.sh | sort -V`; do
         source $file
     done
fi
