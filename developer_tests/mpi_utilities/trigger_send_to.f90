! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!
! One-call driver used by mpi_utils_null_errors_test.f90: under
! null_mpi_utilities_mod.f90, send_to() is documented to always raise
! E_ERR (point-to-point communication is meaningless with one task).
! error_handler(E_ERR, ...) calls exit_all(), which terminates the
! process, so this can only be checked from outside via the exit
! status of a subprocess -- see mpi_utils_null_errors_test.f90.

program trigger_send_to

use types_mod,         only : r8
use mpi_utilities_mod, only : initialize_mpi_utilities, send_to

implicit none

real(r8) :: buf(1) = 0.0_r8

call initialize_mpi_utilities('trigger_send_to')
call send_to(0, buf)

end program trigger_send_to
