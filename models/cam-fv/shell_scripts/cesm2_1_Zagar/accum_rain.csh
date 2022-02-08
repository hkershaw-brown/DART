#!/bin/tcsh

# Script to calculate the accumulated of rain 
# from the average surface flux of rain in a CAM history file.

# I'll test this as a free-standing script on the truth run files.
# Then incorporate it into repack_st_archive.csh for the OSSE and hindcasts.

set casename = Zagar_OSSE_pmo2

set dateroot = 2017-12
set filetype = h1
set hours = 6

foreach hf (`ls ${casename}*${filetype}*${dateroot}`)
   
   ncap2 -A -s "SFRAINACC=SFRAINQM*60*60*${hours}" $hf $hf
end
