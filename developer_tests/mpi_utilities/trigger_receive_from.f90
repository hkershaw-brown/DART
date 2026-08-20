! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!
! One-call driver used by mpi_utils_null_errors_test.f90: see
! trigger_send_to.f90 for why this has to be checked as a subprocess.

program trigger_receive_from

use types_mod,         only : r8
use mpi_utilities_mod, only : initialize_mpi_utilities, receive_from

implicit none

real(r8) :: buf(1) = 0.0_r8

call initialize_mpi_utilities('trigger_receive_from')
call receive_from(0, buf)

end program trigger_receive_from
