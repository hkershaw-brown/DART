#!/bin/bash

echo "creating a script"

cat <<EOF > submit_me.sh
#!/bin/bash

#PBS -A P86850054
#PBS -N my-job
#PBS -j oe
#PBS -k eod
#PBS -q regular
#PBS -l walltime=00:05:00
#PBS -l select=1:ncpus=36:mpiprocs=36

#Example of using /$ vs $

echo \$PWD
echo $PWD
EOF

qsub submit_me.sh
