#!/bin/bash

main() {
set -e

[ -z "$DART" ] && echo "ERROR: Must set DART environment variable" && exit 9

# clean the directory
\rm -f *.o *.mod Makefile .cppdefs

# DART source files
core=$(find $DART/src/core -type f -name "*.f90") 

# build and run preprocess before making any other DART executables
buildpreprocess

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

}

#-------------------------
# Build a program 
# Arguements: 
#  program name
# Globals:
#  DART - root of DART
#  core - directory containing core DART source code
#-------------------------
function buildit() {
 $DART/build_templates/mkmf -v1 -p $1 -a $DART $DART/src/programs/$1/path_names_$1 \
     $DART/src/programs/$1 \
     $core \
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

#-------------------------
# Build and run preprocess
# Arguements: 
#  none
# Globals:
#  DART - root of DART
#-------------------------
function buildpreprocess() {
 $DART/build_templates/mkmf -p preprocess -a $DART $DART/src/programs/preprocess/path_names_preprocess
 make
 ./preprocess
}

main "$@"
