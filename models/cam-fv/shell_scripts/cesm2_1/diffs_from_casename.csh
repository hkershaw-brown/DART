#!/bin/tcsh

set ssdir = models/cam-fv/shell_scripts/cesm2_1
set csdir = /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011
set files = (DART_CASES_scripts \
   Wall_timer \
   data_scripts_offline_setup.csh \
   find_params.csh \
   params.occurances \
   review_list \
   sed_these.csh \
   submit_compress.csh \
   submit_compress_hist.csh \
   submit_no_buildnml.csh \
)

foreach f ($files)
   echo $f
   if (-d $f) then
      ls -l $f
   else if (-f $csdir/$f) then
      diffuse $csdir/$f $f
   else
      vi $f
   endif
end


