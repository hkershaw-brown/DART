#!/bin/tcsh

# Update these from $CASEROOT:
#             DART_config \
#             setup_advanced \
foreach f ( \
            assimilate.csh \
            compress.csh \
            data_scripts.csh \
            diags_rean.csh \
            launch_cf.sh \
            matlab_norm.csh \
            mv_to_campaign.csh \
            no_assimilate.csh \
            pre_purge_check.csh \
            pre_submit.csh \
            purge.csh \
            repack_project.csh \
            repack_st_arch.csh \
            submit_compress.csh \
            submit_compress_hist.csh \
          )
#    ls -l $f* /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/$f
   diffuse /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/$f $f* 
end

exit

Import these from $CASEROOT?:
 add_user_docn_streams.csh
 tar_obs_seq_qcmd.csh
 unpack_rest.csh
 update_dart_namelists

Commit any of these here in shell_scripts?
 backup_manually.csh
 compress_hist.csh
 data_scripts_offline_setup.csh
 diffs_from_casename.csh
 find_params.csh
 obs_seq_tool_series.csh
 params.occurances
 sed_these.csh
 setup_advanced_Rean_2017
 setup_advanced_Test4
 setup_hybrid
 setup_single_from_ens
 sh_scripts_2020-12-29
 spinup_single
 standalone.pbs
 submit_no_buildnml.csh
 test_assimilate.csh
