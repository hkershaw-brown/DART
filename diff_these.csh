#!/bin/tcsh

# Still to do
#            ../work/path_names_filter )

foreach f ( \
   observations/obs_converters/obs_error/ncep_obs_err_mod.f90 \
   assimilation_code/modules/assimilation/filter_mod.f90 \
   assimilation_code/modules/utilities/ensemble_manager_mod.f90 \
   assimilation_code/programs/obs_diag/threed_sphere/obs_diag.f90)

   # -y = launch diff tool without asking
   git difftool -y HEAD $f
end

# Done
#            DART_config.template \
#            assimilate.csh.template \
#            compress.csh \
#            launch_cf.sh \
#            mv_to_campaign.csh \
#            no_assimilate.csh.template \
#            purge.csh \
#            repack_st_arch.csh \
#            setup_advanced \
#            setup_advanced_Rean_2017 \
#            test_assimilate.csh \
#    setup_hybrid \
#    setup_single_from_ens \
#    spinup_single \
#    standalone.pbs )

# Notes
#     setup_advanced_Rean_2017
#                         save because it's what was used (for a different case)?
#                         or rely on the copy in its own $CASEROOT 
#                         (which we have no plans to archive)?
# Ignoring for now
#         Untracked       cesm2_1/setup_advanced_Rean 
#                         save because it's what was used?
#                         or rely on the copy in $CASEROOT?
#                         More updates may be coming from svn.
