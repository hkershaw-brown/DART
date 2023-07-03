#!/usr/bin/bash

# User variables
tiegcm_root=/glade/scratch/{USER}/DART/TIEGCM/tiegcm2.0/
resolution=5.0 # 2.5 or 5.0
account=XXXXX
num_ens=5


cat << run_tiegcm.sh > EOF
#!/bin/bash
#
#PBS -A $account
#PBS -J 1-$num_ens
#PBS -N tiegcm2.0
#PBS -j oe
#PBS -k eod
#PBS -q regular
#PBS -l walltime=00:10:00
##PBS -l select=1:ncpus=16:mpiprocs=16
#PBS -l select=1:ncpus=32:mpiprocs=32:ompthreads=1


TIEGCM_ROOT=/glade/scratch/${USER}/DART/TIEGCM/tiegcm2.0/

export TGCMDATA=/glade/scratch/${USER}/DART/TIEGCM/DATA/tiegcm_res5.0_data
export MP_LABELIO=YES
export MP_SHARED_MEMORY=yes
#
mem="mem"$(printf "%02d" $PBS_ARRAY_INDEX)
cd $mem

JOBID=`echo ${PBS_JOBID} | cut -d'.' -f1 | cut -d'[' -f1` 

# overwrite F10_7 with value from dart state
if [ -f out_params.nc ]; then 
   echo "Using F10.7 from out_params.nc"
  ./writef10_7.py $(ncdump out_params.nc  | grep 'f10_7 =' | cut -d " " -f 4)
fi

# Execute:
 mpiexec_mpt ./tiegcm.exe tiegcm_res5.0.inp &> tiegcm_res5.0_${JOBID}.out
#
# Save stdout:
$TIEGCM_ROOT/scripts/rmbinchars tiegcm_res5.0_${JOBID}.out # remove any non-ascii chars in stdout file
$TIEGCM_ROOT/scripts/mklogs tiegcm_res5.0_${JOBID}.out     # break stdout into per-task log files
#
# Make tar file of task log files:
tar -cf /glade/scratch/${USER}/DART/TIEGCM/tiegcm2.0/tiegcm_res5.0_${JOBID}.out.tar *task*.out 
rm *task*.out

# increment the start,stop in tiegcm_res5.0.inp
./overwrite.py
EOF
