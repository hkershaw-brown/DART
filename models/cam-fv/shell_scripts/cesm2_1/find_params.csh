#!/bin/tcsh

# Find all the scripts which would like to have
# parameters set from a central params file.

touch params.occurances

foreach script (compress.csh         \
                compress_hist.csh    \
                diags_rean.csh       \
                launch_cf.sh         \
                mv_to_campaign.csh   \
                matlab_norm.csh      \
                pre_purge_check.csh  \
                pre_submit.csh       \
                purge.csh            \
                repack_project.csh   \
                repack_st_arch.csh   \
              )
foreach param (                                         \
               80                                       \
               ncis0006                                 \
               DART/reanalysis                          \
               raeder/Exp                               \
               f.e21.FHIST_BGC.f09_025.CAM6assim.011    \
               glade/scratch                            \
               csfs1                                    \
               scripts/lib/CIME                         \
               'year[ ]*='                              \
               'yr[ ]*='                                \
               'month[ ]*='                             \
               'mo[ ]*='                                \
              )
#    others?  especially that can't be set by xmlquery, or setup_advanced.
   set found = `grep -i -m 1 "$param" $script `
   if ($status == 0) echo "$script : $found" >>&! params.occurances

end
end

