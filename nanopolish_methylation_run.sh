#!/bin/bash
#PBS -q small

# Usage: qsub -F "/path/to/genome.fasta /path/to/reads.fasta [/path/to/reads.bam]" nanopolish_methylation_run.sh
#
# NB: nanopolish relies on being able to access the fast5 files that created your fastq.
# /path/to/reads.fasta (or fastq) must be generated using either `poretools` or `nanopolish extract`
# The paths contained in the fasta header must be accessible (without symlinks!) from ~/tmp
# This is done using `rsync -a /path/to/fast5 ~/tmp/path/to/fast5`
# It is advised to call `nanopolish extract` with relative paths, not absolute paths, for this reason

set -x
cd $PBS_O_WORKDIR
GENOME=$(realpath $1)
FASTA=$(realpath $2)
if [ "$#" -gt 2 ]; then
  BAM=$(realpath $3)
fi

if [ $(echo $FASTA | grep -c -e "a$") -gt 0 ]; then 
  FMT="fasta"
elif [ $(echo $FASTA | grep -c -e "q$") -gt 0 ]; then 
  FMT="fastq"
else
  echo "ERROR: $FASTA format not recognised"
  exit 1
fi
N=10000
TMP_DIR="$PBS_O_HOME/tmp/$(dirname $FASTA)"
SCRIPTS_DIR=$PBS_O_HOME/nanopore-scripts

mkdir -p $TMP_DIR
cd $TMP_DIR
if [ ! -f $(basename $FASTA).1.$FMT ]; then
  if [ "$#" -gt 2 ]; then
    python $SCRIPTS_DIR/split_bam_and_fasta.py -b $BAM -f $FASTA --prefix $(basename $FASTA) --bam-suffix fastq.sorted.bam -n $N
  else
    python $SCRIPTS_DIR/split_fasta.py $FASTA $N
  fi
fi
ARRAY_ID=$(qsub -F "$GENOME $FASTA $TMP_DIR" -t 1-$(ls -1 $TMP_DIR/$(basename $FASTA).*.$FMT | wc -l) $SCRIPTS_DIR/nanopolish_methylation.sh)
qsub -W "depend=afteranyarray:$ARRAY_ID" -F "$GENOME $FASTA $TMP_DIR" $SCRIPTS_DIR/nanopolish_methylation_clean.sh

