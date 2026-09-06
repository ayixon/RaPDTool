#!/bin/bash

filename=$(basename "$1")
file_extension="${filename##*.}"
if [ "$file_extension" = "fasta" ] || [ "$file_extension" = "fna" ]; then
    full_path=$(readlink -f "$(dirname "$1")")
    export APPTAINER_BIND="$full_path"
fi

