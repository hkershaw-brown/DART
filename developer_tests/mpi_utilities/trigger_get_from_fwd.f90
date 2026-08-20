! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!
! One-call driver used by mpi_utils_null_errors_test.f90: see
! trigger_send_to.f90 for why this has to be checked as a subprocess.
! Under null_mpi_utilities_mod.f90, get_from_fwd() raises E_ERR
! unconditionally before touching its window/index arguments, so the
! dummy values below never matter.

program trigger_get_from_fwd

use types_mod,         only : r8
use mpi_utilities_mod, only : initialize_mpi_utilities, get_from_fwd

implicit none

real(r8) :: x(1)

call initialize_mpi_utilities('trigger_get_from_fwd')
call get_from_fwd(0, 0, 1, 1, 1, x)

end program trigger_get_from_fwd
