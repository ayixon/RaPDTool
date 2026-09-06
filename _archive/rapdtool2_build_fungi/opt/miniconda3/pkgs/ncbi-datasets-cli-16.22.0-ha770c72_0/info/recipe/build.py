import os
import platform
import sys
from io import BytesIO
from urllib.request import urlopen
from zipfile import ZipFile


def _determine_filename():
    uname = platform.uname()
    print(f"Platform: {uname}")

    match (uname.system, uname.machine):
        case ("Darwin", _):
            package_name = "darwin-universal.cli.package.zip"
        case ("Linux", "x86_64"):
            package_name = "linux-amd64.cli.package.zip"
        case ("Linux", "armv7l" | "arm"):
            package_name = "linux-arm.cli.package.zip"
        case ("Linux", "aarch64" | "arm64"):
            package_name = "linux-arm64.cli.package.zip"
        case ("Windows", "AMD64" | "x86_64"):
            package_name = "windows-amd64.cli.package.zip"
        case (system, arch):
            raise Exception(f"Unsupported platform: {system}-{arch}")

    return package_name


def _files(zipfile):
    if zipfile.startswith("windows"):
        return ["dataformat.exe", "datasets.exe"]
    return ["dataformat", "datasets"]


# Setup
PREFIX = os.environ["PREFIX"]

BIN_DIR = "{}/bin/".format(PREFIX)
if not os.path.exists(BIN_DIR):
    os.mkdir(BIN_DIR)

if len(sys.argv) != 2:
    raise Exception("Must pass one argument, the version string, to this script")
version = sys.argv[1]
filename = _determine_filename()

url = f"https://github.com/ncbi/datasets/releases/download/v{version}/{filename}"
print(f"URL: {url}")

resp = urlopen(url)
myzip = ZipFile(BytesIO(resp.read()))


for file in _files(filename):
    output = f"{BIN_DIR}/{file}"
    print(f"Writing {output}")
    with open(output, "wb") as fh:
        for line in myzip.open(file).readlines():
            fh.write(line)
    os.chmod(output, 0o755)
