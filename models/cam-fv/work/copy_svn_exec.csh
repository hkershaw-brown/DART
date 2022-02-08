#!/bin/tcsh

set svn_dir = /glade/u/home/raeder/DART/reanalysis/models/cam-fv/work/
foreach f ( \
   advance_time \
   closest_member_tool \
   column_rand \
   create_fixed_network_seq \
   create_obs_sequence \
   fill_inflation_restart \
   filter \
   model_mod_check \
   obs_common_subset \
   obs_diag \
   obs_impact_tool \
   obs_seq_to_netcdf \
   obs_sequence_tool \
   perfect_model_obs \
   perturb_single_instance \
   preprocess )
#    minimal_build.csh)

   cp ${svn_dir}/$f .
end
