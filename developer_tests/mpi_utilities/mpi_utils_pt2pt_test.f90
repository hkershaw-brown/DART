! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!
! Exercises send_to/receive_from between tasks 0 and 1, at several
! sizes (including one large enough to span more than one internal
! packing chunk), checking the received values against a known
! sender-side pattern rather than just "not the initial fill value"
! (see developer_tests/mpi_utilities/tests/ftest_sendrecv.f90 for the
! print-and-eyeball precursor this generalizes).
!
! Requires >= 2 MPI tasks; only meaningful built with mpi/mpif08.
! (The nompi behavior of send_to/receive_from -- raising E_ERR -- is
! covered separately by mpi_utils_null_errors_test.f90, since that
! aborts the process and can't be asserted on in-line here.)

program mpi_utils_pt2pt_test

use types_mod,         only : r8
use mpi_utilities_mod, only : initialize_mpi_utilities, finalize_mpi_utilities, &
                               task_count, my_task_id, send_to, receive_from, &
                               sum_across_tasks

implicit none

integer, parameter :: NSIZES = 5
integer, parameter :: SIZES(NSIZES) = (/ 1, 2, 3, 50, 5000 /)

integer :: ntasks, mytask, i, n, j
integer :: ntests = 0
integer :: nfail  = 0
real(r8), allocatable :: buf(:), expected(:)
logical :: passed
character(len=64) :: label

call initialize_mpi_utilities('mpi_utils_pt2pt_test')

ntasks = task_count()
mytask = my_task_id()

if (ntasks < 2) then
   if (mytask == 0) write(*, '(A)') 'FAIL: mpi_utils_pt2pt_test requires at least 2 MPI tasks'
   call finalize_mpi_utilities()
   stop 1
endif

do i = 1, NSIZES

   n = SIZES(i)
   allocate(buf(n), expected(n))
   expected = (/ (1000.0_r8 + real(j, r8), j = 1, n) /)

   if (mytask == 0) then
      buf = expected
      call send_to(1, buf)
      passed = .true.   ! sender has nothing local to verify beyond returning
   else if (mytask == 1) then
      buf = -1.0_r8
      call receive_from(0, buf)
      passed = all(abs(buf - expected) < 1.0e-12_r8)
   else
      passed = .true.   ! bystander task, not part of this exchange
   endif

   deallocate(buf, expected)

   write(label, '(A,I0,A)') 'send_to/receive_from round-trip, ', n, ' element(s)'
   call check_all(trim(label), passed)

enddo

if (mytask == 0) then
   if (nfail == 0) then
      write(*, '(A,I0,A)') 'PASS: mpi_utils_pt2pt_test: all ', ntests, ' checks passed'
   else
      write(*, '(A,I0,A,I0,A)') 'FAIL: mpi_utils_pt2pt_test: ', nfail, ' of ', ntests, ' checks failed'
   endif
endif

call finalize_mpi_utilities()

if (nfail > 0) stop 1

contains

!-----------------------------------------------------------------------------
!> Evaluate a per-task condition on every task, reduce it with
!> sum_across_tasks, and have task 0 print one PASS/FAIL line for the
!> reduced (all-tasks-agree) result.  Tasks not participating in a
!> given exchange pass in .true. so they don't mask a real failure.

subroutine check_all(label, local_condition)

character(len=*), intent(in) :: label
logical,          intent(in) :: local_condition

integer :: local_flag, global_sum
logical :: all_passed

local_flag = 0
if (local_condition) local_flag = 1

call sum_across_tasks(local_flag, global_sum)

all_passed = (global_sum == ntasks)

ntests = ntests + 1
if (.not. all_passed) nfail = nfail + 1

if (mytask == 0) then
   if (all_passed) then
      write(*, '(A,A)') 'PASS: ', trim(label)
   else
      write(*, '(A,A,A,I0,A,I0,A)') 'FAIL: ', trim(label), &
                                     ' (', global_sum, ' of ', ntasks, ' tasks passed)'
   endif
endif

end subroutine check_all

end program mpi_utils_pt2pt_test
