

set -ex



python -V
python3 -V
2to3 -h
pydoc -h
python3-config --help
python run_test.py
python -c "from zoneinfo import ZoneInfo; from datetime import datetime; dt = datetime(2020, 10, 31, 12, tzinfo=ZoneInfo('America/Los_Angeles')); print(dt.tzname())"
python -m venv test-venv
python -c "import sysconfig; print(sysconfig.get_config_var('CC'))"
for f in ${CONDA_PREFIX}/lib/python*/_sysconfig*.py; do echo "Checking $f:"; if [[ `rg @ $f` ]]; then echo "FAILED ON $f"; cat $f; exit 1; fi; done
test ! -f ${PREFIX}/lib/libpython${PKG_VERSION%.*}.a
test ! -f ${PREFIX}/lib/libpython${PKG_VERSION%.*}.nolto.a
pushd tests
pushd distutils
python setup.py install -v -v
python -c "import foobar"
popd
pushd embedding-interpreter
bash build-and-test.sh
popd
pushd cmake
bash run_cmake_test.sh 3.9.12
popd
pushd processpoolexecutor-max_workers-61
python ppe.py
popd
popd
exit 0
