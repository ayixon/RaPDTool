#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
PATH=$SCRIPTPATH:$PATH
MB=metabat2
SUM=jgi_summarize_bam_contig_depths
BADMAP=${BADMAP:=0}
PCTID=${PCTID:=97}
MINDEPTH=${MINDEPTH:=1.0}

if ! $MB --help 2>/dev/null
then
  echo "Please ensure that the MetaBAT binaries are in your PATH: Could not find $MB" 2>&1
  exit 1
fi

if ! $SUM 2>/dev/null
then
  echo "Please ensure that the MetaBAT binaries are in your PATH: Could not find $SUM" 2>&1
  exit 1
fi

USAGE="$0 <select metabat options> assembly.fa sample1.bam [ sample2.bam ...]
You can specify any metabat options EXCEPT:
  -i --inFile
  -o --outFile
  -a --abdFile

Also for depth calculations stage only, you can set the following environmental variables:

  PCTID=${PCTID}          -- reads below this threshold will be discarded
  BADMAP=${BADMAP}          -- output the discarded reads to a sub directory
  MINDEPTH=${MINDEPTH}      -- require contigs to have this minimum depth to be output
  
For full metabat options: $MB -h
"

#outname=
#metabatopts="--verbose --debug"
metabatopts=""
for arg in $@
do
  if [ -f "$arg" ]
  then
    break
  fi
  outname="${arg}"
  metabatopts="$metabatopts $arg"
  shift
done

if [ $# -lt 2 ]
then
  echo "$USAGE" 1>&2 
  exit 1
fi

assembly=$1
shift
if [ ! -f "$assembly" ]
then
  echo "Please specify the assembly fasta file: $assembly does not exist" 1>&2
  exit 1
fi

for bam in $@
do
  if [ ! -f "$bam" ]
  then
    echo "Could not find the expected bam file: $bam" 1>&2
    exit 1
  fi
done

set -e

depth=${assembly##*/}.depth.txt
lock=$depth.BUILDING

waitforlock()
{
  while [ -L "$lock" ]
  do
    echo "Waiting for $lock to be complete before continuing $(date)"
    sleep 60
  done
}

cleanup()
{
  rm -f $lock
}
trap cleanup 0 1 2 3 15


waitforlock
badmap=${assembly##*/}.d
badmapopts=
if [ "$BADMAP" != '0' ]
then
  mkdir -p ${badmap}
  badmapopts="--unmappedFastq ${badmap}/badmap"
fi

if [ ! -f "${depth}" ] && ln -s "$(uname -n) $$" $lock
then
    if [ ! -f "${depth}" ]
    then
        sumopts="--outputDepth ${depth} --percentIdentity ${PCTID} --minContigLength 1000 --minContigDepth ${MINDEPTH} ${badmapopts} --referenceFasta ${assembly}"
        echo "Executing: '$SUM $sumopts $@' at `date`"
        $SUM $sumopts $@
        echo "Finished $SUM at `date`"
    fi

    echo "Creating depth file for metabat at `date`"

    rm $lock
else
  waitforlock
  echo "Skipping $SUM as $depth already exists"
fi

outname=${assembly##*/}.metabat-bins${outname}-$(date '+%Y%m%d_%H%M%S')/bin
echo "Executing: '$MB $metabatopts --inFile $assembly --outFile $outname --abdFile ${depth}' at `date`"
$MB $metabatopts --inFile $assembly --outFile $outname --abdFile ${depth}
echo "Finished $MB at `date`"
