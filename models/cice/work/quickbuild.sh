#!/bin/bash

main() {
set -e

[ -z "$DART" ] && echo "ERROR: Must set DART environment variable" && exit 9

source $DART/build_templates/buildfunctions.sh

# clean the directory
\rm -f *.o *.mod Makefile .cppdefs

# DART source files
findsrc threed_sphere

# build and run preprocess before making any other DART executables
buildpreprocess

programs=( \
advance_time \
closest_member_tool \
create_fixed_network_seq \
create_obs_sequence \
fill_inflation_restart \
filter \
model_mod_check \
obs_common_subset \
obs_selection \
obs_seq_coverage \
obs_seq_to_netcdf \
obs_seq_verify \
obs_sequence_tool \
perfect_model_obs \
perturb_single_instance \
wakeup_filter \
)

#obs_diag \

cice_programs=(
cice_to_dart
dart_to_cice
)

n=$((${#programs[@]}+${#cice_programs[@]}))

i=1
for p in ${programs[@]}; do
  echo "Building " $p "build " $i " of " $n
  buildit $p
  ((i++))
done

for p in ${cice_programs[@]}; do
  echo "Building " $p "build " $i " of " $n
  build $p
  ((i++))
done

}

main "$@"
