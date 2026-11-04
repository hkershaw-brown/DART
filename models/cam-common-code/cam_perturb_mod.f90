module cam_perturb_mod

! Generate an ensemble from a single CAM state by perturbing a user-selected
! list of fields.  The settings come from the model_mod's namelist and are
! passed in as arguments; this module reads no namelist and keeps no state.

use types_mod,            only : r8, i8
use utilities_mod,        only : E_ERR, error_handler
use obs_kind_mod,         only : get_num_quantities, get_index_for_quantity
use state_structure_mod,  only : get_model_variable_indices
use ensemble_manager_mod, only : ensemble_type, get_my_num_vars, get_my_vars
use random_seq_mod,       only : random_seq_type, init_random_seq, random_gaussian
use mpi_utilities_mod,    only : my_task_id

implicit none
private

public :: cam_pert_model_copies, MAX_PERT

! version controlled file description for error handling, do not edit
character(len=*), parameter :: source   = 'cam_perturb_mod.f90'
character(len=*), parameter :: revision = ''
character(len=*), parameter :: revdate  = ''

! maximum number of fields you can list to be perturbed
! to generate an ensemble if starting from a single state.
integer, parameter :: MAX_PERT = 100

contains

!--------------------------------------------------------------------
!> if the namelist is set to not use this custom routine, the default
!> dart routine will add 'pert_amp' of noise to every field in the state
!> to generate an ensemble from a single member.  if it is set to true
!> this routine will be called.  the pert_amp will be ignored, and the
!> given list of quantities will be perturbed by the given amplitude
!> (which can be different for each field) to generate an ensemble.
!> the model_mod's pert_model_copies must still accept (and ignore) pert_amp.
subroutine cam_pert_model_copies(state_ens_handle, ens_size, custom_routine_to_generate_ensemble, &
                                 fields_to_perturb, perturbation_amplitude, interf_provided)

type(ensemble_type), intent(inout) :: state_ens_handle
integer,             intent(in)    :: ens_size
logical,             intent(in)    :: custom_routine_to_generate_ensemble
character(len=*),    intent(in)    :: fields_to_perturb(MAX_PERT)
real(r8),            intent(in)    :: perturbation_amplitude(MAX_PERT)
logical,             intent(out)   :: interf_provided

type(random_seq_type) :: seq

integer :: iloc, jloc, vloc, myqty
integer :: max_qtys, j

integer(i8) :: i, state_items
integer(i8), allocatable :: my_vars(:)

logical,  allocatable :: do_these_qtys(:)
real(r8), allocatable :: perturb_by(:)

character(len=*), parameter :: routine = 'cam_pert_model_copies'
character(len=512) :: string1

! set by namelist to select using the default routine in filter
! (adds the same noise to all parts of the state vector)
! or the code here that lets you specify which fields get perturbed.
if (custom_routine_to_generate_ensemble) then
   interf_provided = .true.
else
   interf_provided = .false.
   return
endif

! make sure each task is using a different random sequence
call init_random_seq(seq, my_task_id())

max_qtys = get_num_quantities()
allocate(do_these_qtys(0:max_qtys), perturb_by(0:max_qtys))

do_these_qtys(:) = .false.
perturb_by(:)    = 0.0_r8

! this loop is over the number of field names/perturb values
! in the namelist.  it quits when it finds a blank field name.
do i=1, MAX_PERT
   if (fields_to_perturb(i) == '') exit

   myqty = get_index_for_quantity(fields_to_perturb(i))
   if (myqty < 0) then
      string1 = 'unrecognized quantity name in "fields_to_perturb" list: ' // &
                trim(fields_to_perturb(i))
      call error_handler(E_ERR,routine,string1,source,revision,revdate)
   endif

   do_these_qtys(myqty) = .true.
   perturb_by(myqty)    = perturbation_amplitude(i)
enddo

! get the global index numbers of the part of the state that 
! we have in this task.  here is an example of how to work with
! just the part of the state that is on the current task.
state_items = get_my_num_vars(state_ens_handle)
allocate(my_vars(state_items))
call get_my_vars(state_ens_handle, my_vars)

! this loop is over all the subset of the state items 
! that are on this MPI task.
do i=1, state_items

   ! for each global index number in the state vector find
   ! what quantity it is. (iloc,jloc,vloc are unused here)
   call get_model_variable_indices(my_vars(i), iloc, jloc, vloc, kind_index=myqty)

   ! if myqty is in the namelist, perturb it.  otherwise cycle
   if (.not. do_these_qtys(myqty)) cycle

   ! this loop is over the number of ensembles
   do j=1, ens_size
      state_ens_handle%copies(j, i) = random_gaussian(seq, state_ens_handle%copies(j, i), perturb_by(myqty))
   enddo

enddo

deallocate(my_vars)
deallocate(do_these_qtys, perturb_by)

end subroutine cam_pert_model_copies

end module cam_perturb_mod
