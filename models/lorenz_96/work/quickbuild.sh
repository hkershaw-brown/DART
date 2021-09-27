#!/bin/bash

main() {
set -e

[ -z "$DART" ] && echo "ERROR: Must set DART environment variable" && exit 9

source $DART/build_templates/buildfunctions.sh

programs=( \
closest_member_tool \
create_fixed_network_seq \
create_obs_sequence \
fill_inflation_restart \
filter \
integrate_model \
model_mod_check \
obs_common_subset \
obs_diag \
obs_sequence_tool \
perfect_model_obs \
)

model_programs=(\
)

# clean the directory
\rm -f *.o *.mod Makefile .cppdefs

# DART source files
findsrc oned

# build and run preprocess before making any other DART executables
buildpreprocess

if [ ! -z "$1" ] ; then
    if [[ " ${programs[*]} " =~ " ${1} " ]]; then
       # whatever you want to do when array contains value
       echo "building " $1
       buildit $1
       exit
    elif [[ " ${model_programs[*]} " =~ " ${1} " ]];then 
       echo "building " $1
       build $1
       exit
    else
       echo "ERROR: unknown program" $1
    fi
else 
   echo "no args"
fi
exit

i=1
for p in ${programs[@]}; do
  echo "Building " $p "build " $i " of " ${#programs[@]}
  buildit $p
  ((i++))
done

# clean up
\rm -f *.o *.mod

}

main "$@"
