! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!

!> test program for computing ncep observation errors

program obs_ncep_error_test

use        types_mod, only : r8
use    utilities_mod, only : initialize_utilities, finalize_utilities, &
                             error_handler, E_ERR, E_MSG

use      obs_err_mod, only : rawin_temp_error

implicit none

! version controlled file description for error handling, do not edit
character(len=*), parameter :: source   = "obs_ncep_error_test"
character(len=*), parameter :: revision = ""
character(len=*), parameter :: revdate  = ""


!----------------------------------------------------------------
! Start of the program

call initialize_utilities(source)

call testit_temperature(1000.0_r8)
call testit_temperature(500.0_r8)
call testit_temperature(100.0_r8)
call testit_temperature(1.0_r8)
call testit_temperature(0.01_r8)

call finalize_utilities(source)

!---------------------------------------------------------------------
! end of main program.
!---------------------------------------------------------------------


contains


!---------------------------------------------------------------------
subroutine testit_temperature(millibars)
real(r8), intent(in) :: millibars

real(r8) :: retval
character(len=128) :: msg

retval = rawin_temp_error(millibars)

write(msg, *) 'input of ', millibars, ' millibars returns a temperature error of ', retval
call error_handler(E_MSG, source, msg)

end subroutine testit_temperature


!---------------------------------------------------------------------
end program obs_ncep_error_test

