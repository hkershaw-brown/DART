#!/bin/tcsh

foreach script (compress.csh \
                compress_hist.csh \
                diags_rean.csh \
                launch_cf.sh \
                mv_to_campaign.csh \
                matlab_norm.csh \
                pre_purge_check.csh \
                pre_submit.csh \
                repack_project.csh \
                repack_st_arch.csh )
#                 purge.csh \
   if (-f $script) then
      vi $script
   else if (-f Reviewing_2019-8/$script) then
      cp Reviewing_2019-8/$script .
      vi $script
   else if (-f /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/$script) then
      cp /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/$script .
      vi $script
   else
      echo "find $script "
   endif
end

# DONE; Remove svn data from each.
# DONE; Update copyright 

# Summary list of data that could be sedded into files in DART_config:
# (Or some of it could be handled by xml_query in $CASEROOT)
#    NINST 
#    $project
#    $ACCOUNT
#    my_email
#    DART source code (or change to reanalysis_git)
#    CASEROOT 
#    $casename f.e21.FHIST_BGC.f09_025.CAM6assim.011
#    $scratch
#    $csdir
#    case_py_dir from $cesm
#    year and month (and more date parts?)
#    others?  especially that can't be set by xmlquery, or setup_advanced.

# compress.csh; 
#    CASEROOT 
#    NINST are possibilities,
#    but it's (almost) always called by another script, so manual change is OK
# compress_hist.csh; 
#    CASEROOT and NINST are possibilities,
#    $project?
#    $ACCOUNT
#    but it's (almost) always called by another script, so manual change is OK
# diags_rean.csh
#    $ACCOUNT
#    my_email
#    DART source code (or change to reanalysis_git)
#    $project
# mv_to_campaign.csh
#    $scratch
#    $csdir
#    but it's (almost) always called by another script, so manual change is OK
# matlab_norm.csh
# pre_purge_check.csh
#    NINST
#    $csdir
#    $casename
#    But always run interactively(?), so no need/good to hardwire names at the start?
# pre_submit.csh
#    case_py_dir from $cesm
# purge.csh  
#    had dir names that could be sedded in.
# repack_project.csh
#    $CASE{ROOT}  (or let it use $cwd?)
#    $csdir
#    $project
#    $ACCOUNT
#    $my_email
#    NINST
# repack_st_arch.csh
#    >>> get a more current one, that generates yr_mo more consistently.
#    $csdir
#    $project
#    $ACCOUNT
#    $my_email
#    NINST -> 5 * (NINST+1)

