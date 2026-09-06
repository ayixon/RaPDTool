import ruamel_yaml
try:
    import pytest
except ImportError:
    pytest = None

if pytest:
    print('ruamel_yaml.__version__: %s' % ruamel_yaml.__version__)

# version_info is used in the package
# check that it exists and matches __version__
from ruamel_yaml import version_info
ver_string = '.'.join([str(i) for i in version_info])
print(ver_string)
assert ver_string == ruamel_yaml.__version__


"""
# downstream conda config tests
import os
from os.path import join
from subprocess import check_call, check_output
from tempfile import mkdtemp

# test generating full conda config
conda_config_show = check_output('conda config --show'.split())
assert b'channels:' in conda_config_show.splitlines(), conda_config_show
# write to custom temporary condarc file
tmp_dir = mkdtemp()
condarc_path = join(tmp_dir, 'condarc')
with open(condarc_path, 'wb') as condarc:
    condarc.write(conda_config_show)
env = os.environ.copy()
env['CONDARC'] = condarc_path
# test writing to conda config
check_call('conda config --add channels _test_channel_'.split(), env=env)
with open(condarc_path, 'rb') as condarc:
    condarc_content = condarc.read()
    assert b'_test_channel_' in condarc_content, condarc_content
# test reading from conda config
conda_config_show_sources = check_output('conda config --show-sources'.split(), env=env)
assert b'_test_channel_' in conda_config_show_sources, conda_config_show_sources
os.remove(condarc_path)
os.rmdir(tmp_dir)
"""
