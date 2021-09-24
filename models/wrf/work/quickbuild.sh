#!/bin/bash -v

set -e

[ -z "$DART" ] && echo "ERROR: Must set DART environment variable" && exit 9

# Build for DART programs

function buildit() {
 $DART/build_templates/mkmf -p $1 -a $DART  $DART/src/programs/$1/path_names_$1 \
     $DART/src/programs/$1 \
     $DART/src/core \
     $DART/src/location/threed_sphere \
     $DART/src/location/utilities \
     $DART/src/null_mpi \
     $DART/models/utilities/default_model_mod.f90 \
     $DART/observations/forward_operators/obs_def_mod.f90 \
     $DART/observations/forward_operators/obs_def_utilities_mod.f90 \
     $DART/src/model_mod_tools/test_interpolate_threed_sphere.f90 \
     ../src/WRF_BC \
     ../src/WRF_DART_utilities \
     ../src

 make $1
}

function build() {
 $DART/build_templates/mkmf -p $1 ../src/programs/$1.f90 \
     $DART/src/core \
     $DART/src/location/threed_sphere \
     $DART/src/location/utilities \
     $DART/src/null_mpi \
     $DART/models/utilities/default_model_mod.f90 \
     $DART/observations/forward_operators/obs_def_mod.f90 \
     $DART/observations/forward_operators/obs_def_utilities_mod.f90 \
     $DART/src/model_mod_tools/test_interpolate_threed_sphere.f90 \
     ../src/WRF_BC \
     ../src/WRF_DART_utilities \
     ../src
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
#radiance_obs_to_netcdf \  # needs rttov

wrf_programs=(
add_pert_where_high_refl \
advance_cymdh \
convertdate \ 
ensemble_init \
pert_wrf_bc \
replace_wrf_fields \
select \
update_wrf_bc \ 
wrf_dart_obs_preprocess
)


n=$((${#programs[@]}+${#wrf_programs[@]}))

i=1
for p in ${programs[@]}; do
  echo "Building " $p "build " $i " of " $n
  buildit $p
  ((i++))
done

for p in ${wrf_programs[@]}; do
  echo "Building " $p "build " $i " of " $n
  build $p
  ((i++))
done

# clean up
\rm -f *.o *.mod

