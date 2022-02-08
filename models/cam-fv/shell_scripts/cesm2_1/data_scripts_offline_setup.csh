#!/bin/tcsh

set echo verbose 

setenv PROJECT      NCIS0006
setenv email        raeder@ucar.edu

setenv case         f.e21.FHIST_BGC.f09_025.CAM6assim.011
setenv caseroot     /glade/work/${USER}/Exp/${case}
setenv dartroot     /glade/u/home/${USER}/DART/reanalysis_git
setenv DART_SCRIPTS_DIR   ${dartroot}/models/cam-fv/shell_scripts/cesm2_1

setenv cesmtag      cesm2_1_relsd_m5.6
setenv cesmroot     /glade/work/${USER}/Models/${cesmtag}
setenv CIMEROOT     $cesmroot/cime

setenv projdir      /glade/p/nsc/ncis0006/Reanalyses
setenv campdir      /gpfs/csfs1/cisl/dares/Reanalyses
setenv baseobsdir   /glade/p/cisl/dares/Observations/NCEP+ACARS+GPS+AIRS/Thinned_x9x10

setenv cime_output  /glade/scratch/${USER}
setenv archdir      ${cime_output}/${case}/archive


setenv save_every_Mth_day_restart Monday
setenv num_instances   80

set DART_CESM_scripts = `pwd`

cd $caseroot

foreach script (compress.csh           \
                compress_hist.csh      \
                diags_rean.csh         \
                launch_cf.sh           \
                mv_to_campaign.csh     \
                matlab_norm.csh        \
                pre_purge_check.csh    \
                pre_submit.csh         \
                purge.csh              \
                repack_project.csh     \
                repack_st_arch.csh     \
                submit_compress.csh    \
                submit_compress_hist.csh)
   if (-f ${DART_SCRIPTS_DIR}/${script}) then
      # $COPY -f ${VERBOSE} ${DART_SCRIPTS_DIR}/${script} . || exit 43
      if (-f $script) then
         mv $script Before_data_scripts_test
      else
         echo "No $script to move"
      endif

      sed -e  "s#YOUR_ACCOUNT#your_account#" \
          -e  "s#YOUR_EMAIL#your_email#" \
          -e  "s#YOUR_CASEROOT#your_caseroot#" \
          ${DART_SCRIPTS_DIR}/${script}  > ${script}
      chmod 755 ${script}
   else
      echo "ERROR: no ${script} in  ${DART_SCRIPTS_DIR}"
      exit 45
   endif
end

# Fill the DART_config script with information it needs and copy it to caseroot.
# DART_config can be run at some later date if desired, but it must be run
# from a caseroot directory.

if ( -e ${DART_CESM_scripts}/DART_config.template ) then
   sed -e "s#your_dart_path#${dartroot}#" \
       -e "s#your_setup_script_dir#$DART_CESM_scripts#" \
       -e "s#your_observation_path#${baseobsdir}#" \
       -e "s#your_account#${PROJECT}#" \
       -e "s#your_email#${email}#" \
       -e "s#your_caseroot#${caseroot}#" \
       -e "s#days_between_archiving_restarts#${save_every_Mth_day_restart}#" \
       < ${DART_CESM_scripts}/DART_config.template \
       >! DART_config  || exit 20
else
   echo "ERROR: the script to configure for data assimilation is not available."
   echo "       DART_config.template MUST be in $DART_CESM_scripts "
   exit 22
endif
chmod 755 DART_config
# Instead of running the whole DART_config,
# just run the parts dealing with the new scripts.
# ./DART_config || exit 80
# That was done in the first loop over scripts.


# ==============================================================================
# Create the parameters file which many scripts will execute to get 
# common environment variables.
# ==============================================================================
cat << EndOfText >! data_scripts.csh
#!/bin/csh -f

# This script defines data/arguments/parameters
# used by many non-CESM scripts in the workflow.

setenv  data_NINST            $num_instances
setenv  data_proj_space       $projdir
setenv  data_DART_src         $dartroot
setenv  data_CASEROOT         $caseroot
setenv  data_CASE             $case
setenv  data_scratch          ${cime_output}/${case}
setenv  data_campaign         $campdir
setenv  data_CESM_python      $CIMEROOT/scripts/lib/CIME 
setenv  data_DOUT_S_ROOT      $archdir

setenv CONTINUE_RUN \`./xmlquery CONTINUE_RUN --value\`
if (\$CONTINUE_RUN == FALSE) then
   set START_DATE = \`./xmlquery RUN_START_DATE --value\`
   set parts = \`echo \$START_DATE | sed -e "s#-# #"\`
   setenv data_year \$parts[1]
   setenv data_month \$parts[2]

else if (\$CONTINUE_RUN == TRUE) then
   # Get date from an rpointer file
   if (! -f \${data_scratch}/run/rpointer.atm_0001) then
      echo "CONTINUE_RUN = TRUE but "
      echo "\${data_scratch}/run/rpointer.atm_0001 is missing.  Exiting"
      exit 19
   endif
   set FILE = \`head -n 1 \${data_scratch}/run/rpointer.atm_0001\`
   set ATM_DATE_EXT = \$FILE:e
   set ATM_DATE     = \`echo \$ATM_DATE_EXT | sed -e "s#-# #g"\`
   setenv data_year   \`echo \$ATM_DATE[1] | bc\`
   setenv data_month  \`echo \$ATM_DATE[2] | bc\`

else
   echo "env_run.xml: CONTINUE_RUN must be FALSE or TRUE (case sensitive)"
   exit

endif

EndOfText
chmod 0755 data_scripts.csh
