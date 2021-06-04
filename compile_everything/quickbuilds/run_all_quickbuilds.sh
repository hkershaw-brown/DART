#!/bin/bash

# options to set
#   1. DART directory
#   2. compiler

DART=../../../DART
FC=pgif90

if [[ ! -d $DART ]] ; then 
  echo "No DART directory: " $DART
  exit 1
fi 
cp mkmf.template $DART/build_templates
cd $DART

# run fixsystem 
# running this once at the beginning otherwise all make commands will
# try and alter the mpi_*_utilities_mod.f90 simultaneously
cd assimilation_code/modules/utilities; ./fixsystem $FC
cd -


# local versions of obs_def_mod.f90 and obs_kind_mod.f90
find . -name input.nml -exec sed -i -e "/^[[:space:]]*#/! s|.*output_obs_def_mod_file.*|output_obs_def_mod_file = './rat/obs_def_mod.f90'|g"    -e "/^[[:space:]]*#/! s|.*output_obs_qty_mod_file.*|output_obs_qty_mod_file = './rat/obs_kind_mod.f90'|g"    -e "/^[[:space:]]*#/! s|.*output_obs_kind_mod_file.*|output_obs_qty_mod_file = './rat/obs_kind_mod.f90'|g" {} \;  

my_dir=$(pwd)
pids=()
dirs=()
status=()

while read f; do

cd $f; mkdir rat; find . -name "path_names*" -exec sed -i -e "s|observations/forward_operators/obs_def_mod.f90|${f}/rat/obs_def_mod.f90|g"  \
 -e "s|assimilation_code/modules/observations/obs_kind_mod.f90|${f}/rat/obs_kind_mod.f90|g" {} \; ; ./quickbuild.csh &
pids+=( "$!" )
dirs+=( "$f" )
cd $my_dir

done < ../all_quickbuilds
#done < some_quickbuilds

for pid in ${pids[@]}; do
  #echo "${pid}"
  wait ${pid}
  status+=( "$?" )
done

# looping through the status arr to check exit code for each
i=0
for st in ${status[@]}; do
    if [[ ${st} -ne 0 ]]; then
        echo "$i ${dirs[$i]} failed"
        OVERALL_EXIT=1
    else
        echo "$i  ${dirs[$i]} finished"
    fi
    ((i+=1))
done

