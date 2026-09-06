

set -ex



f2py -h
pytest --pyargs numpy -k "not (_not_a_real_test or test_sincos_float32 or (TestCond and test_nan))"  --durations=100 -v
exit 0
