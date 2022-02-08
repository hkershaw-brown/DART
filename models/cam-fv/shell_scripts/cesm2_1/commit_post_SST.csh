#!/bin/tcsh
# On branch reanalysis
# Changes not staged for commit:
#   (use "git add <file>..." to update what will be committed)
#   (use "git checkout -- <file>..." to discard changes in working directory)
#
#	modified:   ../../../../assimilation_code/programs/obs_diag/threed_sphere/obs_diag.f90
#                   stashed it
git add   DART_config.template \
          assimilate.csh.template \
          compress.csh \
          launch_cf.sh \
          pre_submit.csh \
          setup_advanced 
#
exit

Updates resulting from running Rean_SST12Z_2020

DART_config.template
> Made modified copies of scripts executable

assimilate.csh.template
> Updated to more fully use data_script.csh.
> Added exit when no .i. files are found.
> The filter exec used by the Reanalysis and later tests needs mpt/2.21.

compress.csh
> Updated instructions

launch_cf.sh
> Updated to be consistent with current system version
> and exit if the right batch job env. var. is not found

pre_submit.csh
> Fail if data_scripts.csh fails
> Fixed wc word list usage error.
> Fixed assumption about the existence of stage_cesm_files.template.
> and surrounding if-endifs.
> Check for files named in cam_init_files.
> Added call to python to force rebuilding of a script which is a link.

setup_advanced
> Fix the specification of the start and end years of the SST file.
> Updated the embedded script "data_scripts.csh" to better handle 
> the definition of a data from rpointer and env_run.xml:START_DATE.
> Create user_docn.streams after preview_namelist creates docn.streams.

no changes added to commit (use "git add" and/or "git commit -a")
