#!/bin/bash -v

# Build for DART programs

function buildit() {
 $DART/build_templates/mkmf -p $1 -a $DART path_names_$1
 make
}

# clean the directory
\rm -f *.o *.mod Makefile .cppdefs

# build and run preprocess before making any other DART executables
buildit preprocess
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
obs_diag \
obs_sequence_tool \
perfect_model_obs \
)

i=1
for p in ${programs[@]}; do
  echo "Building " $p "build " $i " of " ${#programs[@]}
  buildit $p
  ((i++))
done




