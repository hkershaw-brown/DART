! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!
! Exercises the identity/utility corner of the mpi_utilities_mod API:
! task_count, my_task_id, iam_task0, get_dart_mpi_comm, task_sync,
! shell_execute, sleep_seconds, start_mpi_timer/read_mpi_timer.
!
! Builds and runs unchanged against mpi_utilities_mod.f90,
! mpif08_utilities_mod.f90, and null_mpi_utilities_mod.f90 -- under
! nompi, task_count()==1, my_task_id()==0 and iam_task0() are exactly
! the assertions that matter.
!
! Every check is evaluated on every task and reduced with
! sum_across_tasks so a single PASS/FAIL line (from task 0 only) means
! "correct on every task", not "correct on the task that happened to
! print".

program mpi_utils_basic_test

use types_mod,         only : r8, digits12
use mpi_utilities_mod, only : initialize_mpi_utilities, finalize_mpi_utilities, &
                               task_count, my_task_id, iam_task0, get_dart_mpi_comm, &
                               task_sync, shell_execute, sleep_seconds, &
                               start_mpi_timer, read_mpi_timer, sum_across_tasks

implicit none

integer         :: ntasks, mytask, rc
real(digits12)  :: base, elapsed
integer         :: ntests = 0
integer         :: nfail  = 0

call initialize_mpi_utilities('mpi_utils_basic_test')

ntasks = task_count()
mytask = my_task_id()

call check_all('task_count() is positive',                        ntasks > 0)
call check_all('my_task_id() is within [0, task_count())',        mytask >= 0 .and. mytask < ntasks)
call check_all('iam_task0() is true only on task 0',               iam_task0() .eqv. (mytask == 0))

! get_dart_mpi_comm() returns a plain integer under mpi_utilities_mod.f90/
! null_mpi_utilities_mod.f90 but an opaque type(MPI_Comm) under
! mpif08_utilities_mod.f90 -- associate lets one line work against
! whichever type this build actually returns, without needing a
! backend-specific declared variable.
associate (mycomm => get_dart_mpi_comm())
   call check_all('get_dart_mpi_comm() returns without error',     .true.)
end associate

! task_sync() is a barrier: correctness here just means every task
! returns from the call at all (a broken implementation would hang,
! not fail this check -- but a hang is its own kind of failure signal).
call task_sync()
call check_all('task_sync() returns on every task',                .true.)

! elapsed time must move forward across a known sleep
call start_mpi_timer(base)
call sleep_seconds(0.2_r8)
elapsed = read_mpi_timer(base)
call check_all('read_mpi_timer() advances after sleep_seconds(0.2)', elapsed >= 0.1_digits12)

! shell_execute must both succeed and propagate a real exit code
rc = shell_execute('exit 0')
call check_all('shell_execute() returns 0 for a command that exits 0', rc == 0)

rc = shell_execute('exit 7')
call check_all('shell_execute() propagates a nonzero exit code',       rc == 7)

if (mytask == 0) then
   if (nfail == 0) then
      write(*, '(A,I0,A)') 'PASS: mpi_utils_basic_test: all ', ntests, ' checks passed'
   else
      write(*, '(A,I0,A,I0,A)') 'FAIL: mpi_utils_basic_test: ', nfail, ' of ', ntests, ' checks failed'
   endif
endif

call finalize_mpi_utilities()

if (nfail > 0) stop 1

contains

!-----------------------------------------------------------------------------
!> Evaluate a per-task condition on every task, reduce it with
!> sum_across_tasks, and have task 0 print one PASS/FAIL line for the
!> reduced (all-tasks-agree) result.

subroutine check_all(label, local_condition)

character(len=*), intent(in) :: label
logical,          intent(in) :: local_condition

integer :: local_flag, global_sum
logical :: passed

local_flag = 0
if (local_condition) local_flag = 1

call sum_across_tasks(local_flag, global_sum)

passed = (global_sum == ntasks)

ntests = ntests + 1
if (.not. passed) nfail = nfail + 1

if (mytask == 0) then
   if (passed) then
      write(*, '(A,A)') 'PASS: ', trim(label)
   else
      write(*, '(A,A,A,I0,A,I0,A)') 'FAIL: ', trim(label), &
                                     ' (', global_sum, ' of ', ntasks, ' tasks passed)'
   endif
endif

end subroutine check_all

end program mpi_utils_basic_test
