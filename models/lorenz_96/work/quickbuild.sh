#!/bin/bash -v

set -e

[ -z "$DART" ] && echo "ERROR: Must set DART environment variable" && exit 9

# Build for DART programs

function buildit() {
 $DART/build_templates/mkmf -p $1 -a $DART \ $DART/src/programs/$1/path_names_$1 \
     $DART/src/programs/$1 \
     $DART/src/core \
     $DART/src/location/oned \
     $DART/src/location/utilities \
     $DART/src/null_mpi \
     .. \
     $DART/models/utilities/default_model_mod.f90 \
     $DART/observations/forward_operators/obs_def_mod.f90 \
     $DART/observations/forward_operators/obs_def_utilities_mod.f90 \
     $DART/src/model_mod_tools/test_interpolate_oned.f90

 make $1
}

function buildpreprocess() {
 $DART/build_templates/mkmf -p preprocess -a $DART $DART/src/programs/preprocess/path_names_preprocess
 make
}

# clean the directory
\rm -f *.o *.mod Makefile .cppdefs

# build and run preprocess before making any other DART executables
buildpreprocess
./preprocess

programs=( \
closest_member_tool \
create_fixed_network_seq \
create_obs_sequence \
fill_inflation_restart \
filter \
integrate_model \
model_mod_check \
obs_common_subset \
#obs_diag \
obs_sequence_tool \
perfect_model_obs \
)

i=1
for p in ${programs[@]}; do
  echo "Building " $p "build " $i " of " ${#programs[@]}
  buildit $p
  ((i++))
done

# clean up
\rm -f *.o *.mod

