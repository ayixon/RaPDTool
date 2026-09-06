

set -ex



if pip show ruamel.yaml; then exit 1; fi
$PYTHON -m pip install ruamel.yaml
$PYTHON -c "import ruamel.yaml"
pip check
exit 0
