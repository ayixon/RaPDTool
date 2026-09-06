#!/bin/bash

if [ ! -s "$1" ] || [[ ! "$1" =~ \.(fasta|fna)$ ]]; then
    rapdtool.sif
else
    apptainer_bind_path=$(which apptainer_bind.sh)
    . "$apptainer_bind_path"
    rapdtool.sif "$@"
fi
