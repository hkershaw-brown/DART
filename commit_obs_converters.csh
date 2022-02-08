#!/bin/tcsh

# List divided by #-------- into several smaller commits?
goto $1

# On branch reanalysis
# Changes to be committed:
#   (use "git restore --staged <file>..." to unstage)
# 	deleted:    observations/obs_converters/reanalysis/AIRS/shell_scripts/download.sh

# Changes not staged for commit:
#   (use "git add <file>..." to update what will be committed)
#   (use "git restore <file>..." to discard changes in working directory)
# Restore
# Stash
# Add
# 
#
#-------------------
ZAGAR:
git checkout -- assimilation_code/modules/utilities/null_mpi_utilities_mod.f90
git checkout -- build_templates/mkmf.template
git add models/cam-fv/shell_scripts/cesm2_1/mv_to_campaign.csh
# Replace hard coded CASEROOT directory with YOUR_CASEROOT.
git add models/cam-fv/shell_scripts/cesm2_1/repack_st_arch.csh
# Enabled PBS.
# Error checking on data_scripts.csh.
# Better check for enough scratch space.
# Replace mistaken data_project with data_proj_space.
# More selective test on whether to archive component history files.
# Nicer output.
git add models/cam-fv/shell_scripts/cesm2_1/repack_st_noglobus.csh
# Like the old, globus enabled one (repack_st_arch.csh)
# but copy all directly to $csdir.
git commit
exit
#------------------------------------------

GPS:
git checkout -- observations/obs_converters/gps/convert_cosmic_gps_cdf.f90
git checkout -- observations/obs_converters/gps/work/quickbuild.csh
git add observations/forward_operators/obs_def_gps_mod.f90
# Added code to automatically allocate space for twice the number of observations 
# to be processed (max_gpsro_obs).
git add observations/obs_converters/reanalysis/gps/shell_scripts/kdr_multi_parallel.batch
# Derived from my_multi_parallel.batch.
# In PBS it parses the job name to get the start and end dates.
# Updated GPS radio occultation observation satlist,
# and new way of using it.
git add observations/obs_converters/reanalysis/gps/shell_scripts/gpsro_to_obsseq.csh
# Removed CDAAC user name and password, which are no longer needed.
# Updated web site where data files are found.
# Converted to use new satlist format and contents.
git add observations/obs_converters/reanalysis/gps/shell_scripts/convert_many_gpsro.csh 
git add observations/obs_converters/reanalysis/gps/shell_scripts/my_convert_many_gpsro.csh 
git add observations/obs_converters/reanalysis/gps/shell_scripts/my_multi_parallel.batch
# Added a note that these won't work with the new gpsro_to_obsseq.csh,
# which needs a satlist as defined in kdr_multi_parallel.batch.
# 
git commit
exit
#------------------------------------------

AIRS:
AIRS scripts used for Reanalysis 2020 obs_seqs

and related changes.

- - - - - -

git add observations/obs_converters/AIRS/AIRS.html
# Namelist variable outputdir changed to outputfile in the source code.
git add observations/obs_converters/reanalysis/AIRS/shell_scripts/convert_airs_L2.csh
# wget context, more current comments at the beginning,
# This is used only to fetch the files.  
# It's named 'convert' because there were more ambitious plans.
# This is not used by multi_parallel.batch.ksh, which calls dodaily.sh,
# which call the convert_airs_L2 executable.
git add observations/obs_converters/reanalysis/AIRS/shell_scripts/input.nml
# Updated filename_seq_list and filename_out to values expected by scripts.
# This is not used by multi_parallel..., which use input.nml.template.
git add observations/obs_converters/reanalysis/AIRS/shell_scripts/input.nml.template
# Replaced old outputdir and datadir with outputfile.
# Replaced thinning numbers with what's used in the Reanalysis.
# Added variables use_NCEP_errs and version.
git add observations/obs_converters/reanalysis/AIRS/shell_scripts/multi_parallel.batch.ksh
# The version of multi_parallel.X Nancy recommended is the ksh version in 
# /glade/p/cisl/dares/Observations/AIRS/work/multi_parallel.batch.ksh,
# which is very different from the version in HEAD as of 2021-11;
# a tcsh+thoar subversion 12575 (2018) from 
#   obs_converters/gps/shell_scripts/multi_parallel.batch, vs 
# a ksh+nancy  subversion  9948 (2016) from 
#   observations/NCEP/prep_bufr/work/multi_parallel.lsf
# So add it as a separate script.
git add   observations/obs_converters/reanalysis/AIRS/shell_scripts/dodaily.sh
# This was missed in the first commits of obs_converters/reanalysis

git commit
exit
#------------------------------------------

NCEP:
git add observations/obs_converters/NCEP/ascii_to_obs/prepbufr_to_obs.f90
# Added details to "invalid location" messages.
git checkout -- observations/obs_converters/NCEP/ascii_to_obs/work/input.nml
# Increased max_gpsro_obs to 2000000, which wasn't enough 
# for the Reanalysis obs sets; It needs to be 2x as large as the number 
# of GPS obs in the window (which was 1,600,000).
git checkout -- observations/obs_converters/NCEP/ascii_to_obs/work/quickbuild.csh
git checkout -- observations/obs_converters/reanalysis/bufr/scripts/ascii_to_obs/multi_parallel.batch
git add observations/obs_converters/reanalysis/bufr/scripts/ascii_to_obs/kdr_multi_parallel.batch
# This is the one Kevin used to make the NCEP obs files for 2020.
# In PBS it parses the job name to get the start and end dates.
git checkout -- observations/obs_converters/reanalysis/bufr/scripts/prep_bufr/my_multi_parallel.batch
# Add a check of the output files, instead of requiring that as a separate step
# outside of this script.
git add observations/obs_converters/reanalysis/bufr/scripts/prep_bufr/kdr_multi_parallel.batch
# This is the one Kevin used to make the NCEP obs files for 2020.
# In PBS it parses the job name to get the start and end dates.
# Remove the 'csh' from the command given to mycmdfile.
# Pass the day number to run_one_prepbufr.csh to enable separate diagnostic files 
# for each day.
# Check more carefully for missing files and persisting workdirs.
git checkout -- observations/obs_converters/reanalysis/bufr/scripts/prep_bufr/my_prepbufr.csh
git add observations/obs_converters/reanalysis/bufr/scripts/prep_bufr/run_one_prepbufr.csh
# Add a the day number to the arguments to enable separate diagnostic files.
git commit
exit
#------------------------------------------

MERGE:
git add observations/obs_converters/reanalysis/merge_progs/domerge.sh 
# Add code to handle failure of obs_seq_tool in a helpful way
# instead of destroying all evidence.
git add observations/obs_converters/reanalysis/README
# Replaced instructions about HPSS.
# Updated gps section to reference the new kdr_multi_parallel.batch,
# which handles the new satlist of platforms and web addresses.
# Included note about max_gpsro_obs needing to be twice the number 
# of GPS obs.
#
git commit
exit
#------------------------------------------

Untracked files not listed (use -u option to show untracked files)
