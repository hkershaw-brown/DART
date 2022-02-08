#!/bin/tcsh

# >>>  Don't commit this to the repository.   <<<
# It submits a job name that's hidden because CESM doesn't want anyone 
# to submit it without using case.submit.
# ./lib/CIME/case/case_submit.py:
#        # This is a resubmission, do not reinitialize test values
? --resubmit?:
    parser.add_argument("--resubmit", action="store_true",
                        help="Used with tests only, to continue rather than restart a test.")
? How about
    parser.add_argument("--skip-preview-namelist", action="store_true",
                        help="Skip calling preview-namelist during case.run.")
    Probably yes.  env_batch.py:
       def _get_supported_args(job, no_batch):
        Returns a map of the supported parameters and their arguments to the given script
        if job in ["case.run", "case.test"]:
            supported["skip_pnl"] = "--skip-preview-namelist"
    I'm testing this in ~/Scripts/submit for f.e21.FHIST_BGC.f09_025.CAM6assim.011
       2011-08-16-64800 to 17-00000



qsub -q R2659748 -l walltime=0:30:00 -A P86850054 -v ARGS_FOR_SCRIPT='--resubmit' .case.run
