#!/bin/bash
#PBS -N filter
#PBS -A P86850054
#PBS -l select=1:ncpus=36:mpiprocs=1
#PBS -l walltime=01:00:00
#PBS -q casper
#PBS -j oe

export TMPDIR=/glade/scratch/$USER/temp
mkdir -p $TMPDIR

### Run program
module -t list
time mpirun ./filter
