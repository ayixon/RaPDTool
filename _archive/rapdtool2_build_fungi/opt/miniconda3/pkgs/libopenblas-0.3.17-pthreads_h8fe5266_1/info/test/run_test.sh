

set -ex



test -f ${PREFIX}/lib/libopenblasp-r0.3.17.so
python -c "import ctypes; ctypes.cdll['${PREFIX}/lib/libopenblasp-r0.3.17.so']"
exit 0
