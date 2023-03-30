#!/bin/bash
#PBS -N filter-gpu
#PBS -A P86850054
#PBS -l select=1:ncpus=1:mpiprocs=1:ngpus=1
#PBS -l walltime=00:05:00
#PBS -q casper
#PBS -j oe

export TMPDIR=/glade/scratch/$USER/temp
mkdir -p $TMPDIR

### Run program
#mpirun ./filter
module -t list

nsys profile --stats=true mpirun ./filter
