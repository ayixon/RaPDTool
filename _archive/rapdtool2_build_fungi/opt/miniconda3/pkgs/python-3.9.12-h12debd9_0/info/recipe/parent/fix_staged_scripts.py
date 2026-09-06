from os.path import isdir, isfile, dirname, join
from sys import argv

import os
import shutil


# Taken and adapted from conda_build/windows.py
def fix_staged_scripts(scripts_dir, arch):
    """
    Fixes scripts which have been installed unix-style to have a .bat
    helper
    """
    if not isdir(scripts_dir):
        return

    import conda_build
    cli_exe = os.path.dirname(conda_build.__file__)
    cli_exe = os.path.join(cli_exe, 'cli-{}.exe'.format(arch))
    if not os.path.exists(cli_exe):
        print("ERROR :: cli_exe {} does not exist".format(cli_exe))
        sys.exit(1)

    for fn in os.listdir(scripts_dir):
        # process all the extensionless files
        if not isfile(join(scripts_dir, fn)) or '.' in fn:
            continue

        # read as binary file to ensure we don't run into encoding errors, see #1632
        with open(join(scripts_dir, fn), 'rb') as f:
            line = f.readline()
            # If it's a #!python script
            if not (line.startswith(b'#!') and b'python' in line.lower()):
                continue
            print('Adjusting unix-style #! script %s, '
                  'and adding a .bat file for it' % fn)
            # copy it with a .py extension (skipping that first #! line)
            with open(join(scripts_dir, fn + '-script.py'), 'wb') as fo:
                fo.write(f.read())
            # now create the .exe file
            # This is hardcoded that conda and conda-build are in the same environment
            base_env = dirname(dirname(os.environ['CONDA_EXE']))
            shutil.copyfile(cli_exe, join(scripts_dir, fn + '.exe'))

        # remove the original script
        os.remove(join(scripts_dir, fn))


fix_staged_scripts(os.environ['SCRIPTS'], argv[1])
