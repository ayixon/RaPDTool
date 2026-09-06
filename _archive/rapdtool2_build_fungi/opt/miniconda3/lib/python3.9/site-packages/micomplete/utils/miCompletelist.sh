#!/bin/bash

# Script to convert list of files to miComplete-compatible
# input tabfile.
# usage: find <genome-dir> -maxdepth 1 -type f \
# | bash miCompletelist.sh > .tab

elementIn () {
	local e match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && echo 0; done
	return 1
}

validext=(
	'fna'
	'faa'
	'gb'
	'gbk'
	'gbff'
	)
set -eu

while read -r fa; do
	extension=$(echo $fa | rev | cut -d "." -f "1" | rev)
	if [[ $(elementIn "$extension" "${validext[@]}") ]]; then
		printf "$(readlink -e $fa)\t$extension\n"
	else
		>&2 echo "$(basename $fa) does not have the correct extension. Excluded."
	fi
done < "${1:-/dev/stdin}"
