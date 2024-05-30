#!/bin/bash
#PBS -N create_ens
#PBS -A P86850054
#PBS -j oe
#PBS -k eod
#PBS -q main
#PBS -l walltime=01:00:00
#PBS -l select=2:ncpus=128:mpiprocs=128


# run: qsub -v "num_ens=2" run_pertub.sh 

### Set temp to scratch
export TMPDIR=${SCRATCH}/${USER}/temp && mkdir -p $TMPDIR

cp ../input.nml.base input.nml
cat <<EOF >> input.nml
&perturb_single_instance_nml
   ens_size               = $num_ens
   input_files            = 'mom6.r.nc'
   output_file_list       = 'output_files.txt'
   perturbation_amplitude = 0.1
   single_restart_file_in = .false.
  /
EOF

ens=$(printf "%04d" $num_ens)

for i in $(seq -w 01 $ens); do echo "mom6.r.mem$i.nc"; done > output_files.txt

mpibind ./perturb_single_instance

