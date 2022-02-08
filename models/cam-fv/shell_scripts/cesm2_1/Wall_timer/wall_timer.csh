#!/bin/tcsh

set divisor = $1

echo cycles_per_job job_minutes min_per_job
set cycles_per_job = 4
while ($cycles_per_job <= 60)
   @ job_minutes = 10 + ( $cycles_per_job * ( 10 + (( $cycles_per_job * 10) / $divisor )))
   @ min_per_job = $job_minutes 
   if ($cycles_per_job > 0) @ min_per_job = $job_minutes / $cycles_per_job
   echo $cycles_per_job $job_minutes $min_per_job
   @ cycles_per_job = $cycles_per_job + 10
end
