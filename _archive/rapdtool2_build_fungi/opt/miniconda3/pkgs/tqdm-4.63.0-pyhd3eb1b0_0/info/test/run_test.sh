

set -ex



pip check
tqdm --help
tqdm -v
pytest -k "not tests_perf"
exit 0
