! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!
! Exercises the broadcast/reduction corner of the mpi_utilities_mod
! API: array_broadcast, broadcast_send/recv, broadcast_flag,
! sum_across_tasks, send_sum_to, send_minmax_to, get_global_max,
! all_reduce_min_max.
!
! The array_broadcast checks are the primary point of this program:
! they specifically regression-cover the array-bounds bug fixed on
! this branch, where icount < size(array) together with
! make_copy_before_broadcast = .true. copied/restored the *whole*
! array into/out of a tmpdata buffer sized to icount. Build this
! target with bounds-checking on (-fbounds-check for gfortran,
! -check bounds for ifx) so the old code would have tripped exactly
! here.
!
! mpi_utilities_nml (in particular make_copy_before_broadcast) is only
! read by this binary because quickbuild.sh builds it against a
! build-time-patched copy of the selected mpi backend source with
! read_namelist forced to .true. -- see build_patched_target() in
! developer_tests/mpi_utilities/work/quickbuild.sh. The shipped
! mpi_utilities_mod.f90/mpif08_utilities_mod.f90 are untouched.

program mpi_utils_collectives_test

use types_mod,         only : r8, i8
use mpi_utilities_mod, only : initialize_mpi_utilities, finalize_mpi_utilities, &
                               task_count, my_task_id, array_broadcast,        &
                               broadcast_send, broadcast_recv, broadcast_flag, &
                               sum_across_tasks, send_sum_to, send_minmax_to,  &
                               get_global_max, all_reduce_min_max

implicit none

real(r8), parameter :: TOL = 1.0e-10_r8

integer :: ntasks, mytask
integer :: ntests = 0
integer :: nfail  = 0

call initialize_mpi_utilities('mpi_utils_collectives_test')

ntasks = task_count()
mytask = my_task_id()

call test_array_broadcast(0)
if (ntasks > 1) call test_array_broadcast(ntasks - 1)

call test_broadcast_send_recv()
call test_broadcast_flag()
call test_sum_across_tasks()
call test_send_sum_to()
call test_send_minmax_to()
call test_get_global_max()
call test_all_reduce_min_max()

if (mytask == 0) then
   if (nfail == 0) then
      write(*, '(A,I0,A)') 'PASS: mpi_utils_collectives_test: all ', ntests, ' checks passed'
   else
      write(*, '(A,I0,A,I0,A)') 'FAIL: mpi_utils_collectives_test: ', nfail, ' of ', ntests, ' checks failed'
   endif
endif

call finalize_mpi_utilities()

if (nfail > 0) stop 1

contains

!-----------------------------------------------------------------------------
!> array_broadcast(), including the icount < size(array) regression case,
!> from the given root. Non-root tasks fill their whole array with a
!> per-task sentinel before the call so a bounds-driven corruption of
!> the untouched tail (positions icount+1:N) would show up as a changed
!> value there, not just a wrong value in the broadcast portion.

subroutine test_array_broadcast(root)

integer, intent(in) :: root

integer,  parameter :: N = 20
integer,  parameter :: ICOUNT = 7
real(r8) :: full(N), partial(N)
real(r8) :: sentinel, expected_head
logical  :: head_ok, tail_ok
integer  :: i
character(len=96) :: label

sentinel = -999.0_r8 - real(mytask, r8)

! -------- full-size broadcast (icount absent) --------
if (mytask == root) then
   full = (/ (100.0_r8 * root + i, i = 1, N) /)
else
   full = sentinel
endif

call array_broadcast(full, root)

if (mytask == root) then
   head_ok = all(abs(full - (/ (100.0_r8 * root + i, i = 1, N) /)) < TOL)
else
   head_ok = all(abs(full - (/ (100.0_r8 * root + i, i = 1, N) /)) < TOL)
endif

write(label, '(A,I0,A)') 'array_broadcast: full array, root ', root, ''
call check_all(trim(label), head_ok)

! -------- regression case: icount < size(array) --------
if (mytask == root) then
   partial = (/ (100.0_r8 * root + i, i = 1, N) /)
else
   partial = sentinel
endif

call array_broadcast(partial, root, icount=ICOUNT)

if (mytask == root) then
   ! root's own array must be completely untouched
   head_ok = all(abs(partial - (/ (100.0_r8 * root + i, i = 1, N) /)) < TOL)
   tail_ok = .true.
else
   ! positions 1:ICOUNT carry the broadcast values ...
   head_ok = all(abs(partial(1:ICOUNT) - (/ (100.0_r8 * root + i, i = 1, ICOUNT) /)) < TOL)
   ! ... and positions ICOUNT+1:N must be untouched (the bug corrupted this)
   tail_ok = all(abs(partial(ICOUNT+1:N) - sentinel) < TOL)
endif

write(label, '(A,I0,A)') 'array_broadcast: icount < size(array), root ', root, ' (regression)'
call check_all(trim(label), head_ok .and. tail_ok)

end subroutine test_array_broadcast

!-----------------------------------------------------------------------------
!> broadcast_send (on task 0) / broadcast_recv (everywhere else), one
!> array and one scalar in the same call, matching the documented pairing.

subroutine test_broadcast_send_recv()

real(r8), parameter :: EXPECTED_SCALAR = 42.5_r8
integer,  parameter :: N = 5
real(r8) :: arr(N), scalar
logical  :: passed
integer  :: i

if (mytask == 0) then
   arr    = (/ (10.0_r8 * i, i = 1, N) /)
   scalar = EXPECTED_SCALAR
   call broadcast_send(0, arr, scalar1=scalar)
   passed = all(abs(arr - (/ (10.0_r8 * i, i = 1, N) /)) < TOL) .and. abs(scalar - EXPECTED_SCALAR) < TOL
else
   arr    = -1.0_r8
   scalar = -1.0_r8
   call broadcast_recv(0, arr, scalar1=scalar)
   passed = all(abs(arr - (/ (10.0_r8 * i, i = 1, N) /)) < TOL) .and. abs(scalar - EXPECTED_SCALAR) < TOL
endif

call check_all('broadcast_send/broadcast_recv: array + scalar from task 0', passed)

end subroutine test_broadcast_send_recv

!-----------------------------------------------------------------------------
!> broadcast_flag(), root sending both .true. and .false.

subroutine test_broadcast_flag()

logical :: flag
integer :: root
logical :: passed

root = 0

flag = (mytask == root)   ! .true. only on root, to start
call broadcast_flag(flag, root)
passed = flag .eqv. .true.
call check_all('broadcast_flag: root broadcasts .true.', passed)

flag = (mytask /= root)   ! .false. only on root, to start
call broadcast_flag(flag, root)
passed = flag .eqv. .false.
call check_all('broadcast_flag: root broadcasts .false.', passed)

end subroutine test_broadcast_flag

!-----------------------------------------------------------------------------
!> sum_across_tasks(), forcing all three generic bindings (int4/int8/real).

subroutine test_sum_across_tasks()

integer     :: addend4, sum4, expected4
integer(i8) :: addend8, sum8, expected8
real(r8)    :: addendr, sumr, expectedr

expected4 = (ntasks * (ntasks + 1)) / 2

addend4 = mytask + 1
call sum_across_tasks(addend4, sum4)
call check_all('sum_across_tasks (int4)', sum4 == expected4)

expected8 = int(expected4, i8)
addend8 = int(mytask, i8) + 1_i8
call sum_across_tasks(addend8, sum8)
call check_all('sum_across_tasks (int8)', sum8 == expected8)

expectedr = real(expected4, r8)
addendr = real(mytask, r8) + 1.0_r8
call sum_across_tasks(addendr, sumr)
call check_all('sum_across_tasks (real)', abs(sumr - expectedr) < TOL)

end subroutine test_sum_across_tasks

!-----------------------------------------------------------------------------
!> send_sum_to(): array sum reduction, result meaningful only on the
!> collecting task -- other tasks pass a trivial .true. into check_all.

subroutine test_send_sum_to()

integer, parameter :: TARGET = 0
real(r8) :: local_val(2), global_val(2), expected(2)
logical  :: passed

local_val(1) = real(mytask, r8) + 1.0_r8
local_val(2) = 2.0_r8 * local_val(1)
global_val   = -1.0_r8

call send_sum_to(local_val, TARGET, global_val)

if (mytask == TARGET) then
   expected(1) = real((ntasks * (ntasks + 1)) / 2, r8)
   expected(2) = 2.0_r8 * expected(1)
   passed = all(abs(global_val - expected) < TOL)
else
   passed = .true.
endif

call check_all('send_sum_to: array sum collected on task 0', passed)

end subroutine test_send_sum_to

!-----------------------------------------------------------------------------
!> send_minmax_to(): min/max reduction, result meaningful only on the
!> collecting task.

subroutine test_send_minmax_to()

integer, parameter :: TARGET = 0
real(r8) :: minmax(2), global_val(2), expected(2)
logical  :: passed

minmax(1) = real(mytask, r8)          ! local min
minmax(2) = real(mytask, r8) + 0.5_r8 ! local max
global_val = -1.0_r8

call send_minmax_to(minmax, TARGET, global_val)

if (mytask == TARGET) then
   expected(1) = 0.0_r8
   expected(2) = real(ntasks - 1, r8) + 0.5_r8
   passed = all(abs(global_val - expected) < TOL)
else
   passed = .true.
endif

call check_all('send_minmax_to: min/max collected on task 0', passed)

end subroutine test_send_minmax_to

!-----------------------------------------------------------------------------
!> get_global_max(): in-place, result must land on every task.

subroutine test_get_global_max()

real(r8) :: maxval_local
logical  :: passed

maxval_local = real(mytask, r8)
call get_global_max(maxval_local)

passed = abs(maxval_local - real(ntasks - 1, r8)) < TOL
call check_all('get_global_max: every task sees the global max', passed)

end subroutine test_get_global_max

!-----------------------------------------------------------------------------
!> all_reduce_min_max(): in-place, element-wise, result on every task.

subroutine test_all_reduce_min_max()

integer, parameter :: N = 3
real(r8) :: min_var(N), max_var(N), expected_min(N), expected_max(N)
integer  :: k
logical  :: passed

do k = 1, N
   min_var(k) = real(mytask, r8) + 10.0_r8 * real(k, r8)
   max_var(k) = min_var(k)
enddo

call all_reduce_min_max(min_var, max_var, N)

do k = 1, N
   expected_min(k) = 0.0_r8              + 10.0_r8 * real(k, r8)
   expected_max(k) = real(ntasks - 1, r8) + 10.0_r8 * real(k, r8)
enddo

passed = all(abs(min_var - expected_min) < TOL) .and. all(abs(max_var - expected_max) < TOL)
call check_all('all_reduce_min_max: element-wise min/max on every task', passed)

end subroutine test_all_reduce_min_max

!-----------------------------------------------------------------------------
!> Evaluate a per-task condition on every task, reduce it with
!> sum_across_tasks, and have task 0 print one PASS/FAIL line for the
!> reduced (all-tasks-agree) result.

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

end program mpi_utils_collectives_test
