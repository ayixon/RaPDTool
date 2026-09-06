#!/usr/bin/env bash
# Run the tests for tzdata

set -ex

exists() {
	FULL_PATH="${PREFIX}/${1}"
	if [ -f "${FULL_PATH}" ]; then
		echo "Found ${1}"
	else
		echo "Could not find ${FULL_PATH}"
		exit 1
	fi
}

for i in share/zoneinfo/{zone,iso3166,zone1970}.tab share/zoneinfo/leapseconds share/zoneinfo/tzdata.zi; do
	exists $i
done
