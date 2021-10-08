#!/bin/bash

main() {
set -e

[ -z "$DART" ] && echo "ERROR: Must set DART environment variable" && exit 9

source $DART/build_templates/buildfunctions.sh
MODEL=wrf

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
obs_diag \
obs_selection \
obs_seq_coverage \
obs_seq_to_netcdf \
obs_seq_verify \
obs_sequence_tool \
perfect_model_obs \
perturb_single_instance \
wakeup_filter \
)

#radiance_obs_to_netcdf \  # needs rttov

model_programs=(
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

buildit $1

}

main "$@"
