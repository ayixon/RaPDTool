#!/bin/bash

# Check where we are.
echo $CONDA_PREFIX

# Check version via import.
python -c "from __future__ import print_function; import conda; print(conda.__version__)"

# Show where the conda commands are.
which conda
which conda-env

# Run some conda commands.
conda --version
conda info
conda env --help

if [[ $run_pytest == "yes" ]]; then
    pytest tests -m "not integration and not installed" -vv || true
fi

# # Brought from the test.commands section in meta.yaml
# # Kept here for reference
# unset CONDA_SHLVL
# eval "$(python -m conda shell.bash hook)"
# conda activate base
# export PYTHON_MAJOR_VERSION=$(python -c "import sys; print(sys.version_info[0])")
# export TEST_PLATFORM=$(python -c "import sys; print('win' if sys.platform.startswith('win') else 'unix')")
# export PYTHONHASHSEED=$(python -c "import random as r; print(r.randint(0,4294967296))") && echo "PYTHONHASHSEED=$PYTHONHASHSEED"
# env | sort
# conda info
# conda create -y -p ./built-conda-test-env
# conda activate ./built-conda-test-env
# echo $CONDA_PREFIX
# [ "$CONDA_PREFIX" = "$PWD/built-conda-test-env" ] || exit 1
# conda deactivate