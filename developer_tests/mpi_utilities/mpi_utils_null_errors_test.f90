! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!
! null_mpi_utilities_mod.f90 documents send_to, receive_from,
! get_from_fwd and get_from_mean as always raising E_ERR (point-to-
! point and one-sided communication are meaningless with a single
! task). error_handler(E_ERR, ...) calls exit_all(), which terminates
! the process before control returns, so this can't be asserted
! in-process the way developer_tests/utilities/error_handler_test.f90
! found out (it just comments its own E_ERR case out). Instead, run
! each forbidden call in its own one-line trigger program (built
! alongside this one) and check that the subprocess exits nonzero --
! the same execute_command_line() idiom mpi_utilities_mod's own
! shell_execute() is built on.
!
! Only meaningful built with nompi: under mpi/mpif08 these routines do
! real communication instead of erroring.

program mpi_utils_null_errors_test

implicit none

integer, parameter :: NTRIGGERS = 4
character(len=32), parameter :: triggers(NTRIGGERS) = (/ character(len=32) :: &
   'trigger_send_to', 'trigger_receive_from', 'trigger_get_from_fwd', 'trigger_get_from_mean' /)

integer :: i, exitstat, cmdstat
integer :: ntests = 0
integer :: nfail  = 0
character(len=256) :: cmd

do i = 1, NTRIGGERS

   cmd = './' // trim(triggers(i)) // ' > /dev/null 2>&1'
   exitstat = 0
   cmdstat  = 0
   call execute_command_line(trim(cmd), exitstat=exitstat, cmdstat=cmdstat)

   ntests = ntests + 1

   if (cmdstat /= 0) then
      nfail = nfail + 1
      write(*, '(A,A,A)') 'FAIL: could not run ', trim(triggers(i)), ' at all (build it first)'
   else if (exitstat == 0) then
      nfail = nfail + 1
      write(*, '(A,A,A)') 'FAIL: ', trim(triggers(i)), &
                           ' exited 0 -- should have aborted under the null MPI module'
   else
      write(*, '(A,A,A)') 'PASS: ', trim(triggers(i)), ' aborts under the null MPI module, as documented'
   endif

enddo

if (nfail == 0) then
   write(*, '(A,I0,A)') 'PASS: mpi_utils_null_errors_test: all ', ntests, ' checks passed'
else
   write(*, '(A,I0,A,I0,A)') 'FAIL: mpi_utils_null_errors_test: ', nfail, ' of ', ntests, ' checks failed'
endif

if (nfail > 0) stop 1

end program mpi_utils_null_errors_test
