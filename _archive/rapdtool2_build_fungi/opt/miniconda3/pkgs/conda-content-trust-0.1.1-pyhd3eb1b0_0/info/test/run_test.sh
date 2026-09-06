

set -ex



pytest -v tests
conda-content-trust --help
exit 0
