! write all copies to a single file
program test_write_single_file

use types_mod, only : r8, i8
use ensemble_manager_mod, only : ensemble_type, init_ensemble_manager
use mpi_utilities_mod, only : initialize_mpi_utilities, finalize_mpi_utilities
use io_filenames_mod, only : file_info_type, file_info_dump
use state_vector_io_mod, only : write_state, set_stage_to_write
use filter_mod, only: initialize_file_information, finalize_single_file_io, ens_size, &
                      count_state_ens_copies
use assim_model_mod, only : static_init_assim_model, get_model_size
use time_manager_mod, only : print_time, increment_time
use adaptive_inflate_mod,  only : adaptive_inflate_type

implicit none

type(ensemble_type) :: state_ens_handle
integer :: num_copies
integer(i8) :: num_vars
integer :: i
type(adaptive_inflate_type) :: prior_inflate, post_inflate

! what is the point of all these?
type(file_info_type) :: file_info_input
type(file_info_type) :: file_info_mean_sd
type(file_info_type) :: file_info_forecast
type(file_info_type) :: file_info_preassim
type(file_info_type) :: file_info_postassim
type(file_info_type) :: file_info_analysis
type(file_info_type) :: file_info_output
type(file_info_type) :: file_info_all

call initialize_mpi_utilities('test_write_single_file')

call static_init_assim_model()
num_vars = get_model_size()

! Copy numbers set in count_state_ens_copies
num_copies = count_state_ens_copies(ens_size, prior_inflate, post_inflate)

call init_ensemble_manager(state_ens_handle, num_copies, num_vars)
state_ens_handle%copies(:,:)  = 1.0_r8

call set_stage_to_write('INPUT', output_stage=.true.)
call set_stage_to_write('FORECAST', output_stage=.true.)
call set_stage_to_write('PREASSIM', output_stage=.true.)
call set_stage_to_write('POSTASSIM', output_stage=.true.)
call set_stage_to_write('ANALYSIS', output_stage=.true.)
call set_stage_to_write('OUTPUT', output_stage=.true.)

! initialize_file_information
! stage_metadata%io_flag: read = 1, write = 2, read/write = 3
!    -> io_filenames_init
!    -> set_filename_info
!    -> set_input_file_info
!       -> set_io_copy_flag
!    -> set_output_file_info
!       -> set_io_copy_flag

! HK ?file_info_mean_sd?
call initialize_file_information(num_copies ,                     &
                                 file_info_input      , file_info_mean_sd,  &
                                 file_info_forecast   , file_info_preassim, &
                                 file_info_postassim  , file_info_analysis, &
                                 file_info_output)


call file_info_dump(file_info_forecast)


! * write input state files
!  do i = 1, number of filter_assim calls
!     * increment time
!     * change the data in copies
!     * write the state
!  enddo
! * write output state files

call write_state(state_ens_handle, file_info_input)

do i = 1, 3
   call print_time(state_ens_handle%current_time)
   state_ens_handle%current_time = increment_time(state_ens_handle%current_time, 60)
   state_ens_handle%copies(:,:) = state_ens_handle%copies(:,:) + 1.0_r8
   call write_state(state_ens_handle, file_info_forecast)
   call write_state(state_ens_handle, file_info_preassim)
   call write_state(state_ens_handle, file_info_postassim)
   call write_state(state_ens_handle, file_info_analysis)
enddo

call write_state(state_ens_handle, file_info_output)


call finalize_single_file_io(file_info_input)
call finalize_single_file_io(file_info_forecast)
call finalize_single_file_io(file_info_preassim)
call finalize_single_file_io(file_info_postassim)
call finalize_single_file_io(file_info_analysis)
call finalize_single_file_io(file_info_output)

call finalize_mpi_utilities()

end program test_write_single_file
