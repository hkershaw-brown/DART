! write all copies to a single file
program test_write_single_file

use types_mod, only : r8, i8
use ensemble_manager_mod, only : ensemble_type, init_ensemble_manager
use mpi_utilities_mod, only : initialize_mpi_utilities, finalize_mpi_utilities
use io_filenames_mod, only : file_info_type
use direct_netcdf_mod, only : write_single_file
use filter_mod, only: initialize_file_information

implicit none

type(ensemble_type) :: state_ens_handle
integer :: num_copies
integer(i8) :: num_vars

! what is the point of all these?
type(file_info_type) :: file_info_input
type(file_info_type) :: file_info_mean_sd
type(file_info_type) :: file_info_forecast
type(file_info_type) :: file_info_preassim
type(file_info_type) :: file_info_postassim
type(file_info_type) :: file_info_analysis
type(file_info_type) :: file_info_output
type(file_info_type) :: file_info_all

num_copies = 5
num_vars = 129


call initialize_mpi_utilities('test_write_single_file')
call init_ensemble_manager(state_ens_handle, num_copies, num_vars)

call initialize_file_information(num_copies ,                     &
                                 file_info_input      , file_info_mean_sd,  &
                                 file_info_forecast   , file_info_preassim, &
                                 file_info_postassim  , file_info_analysis, &
                                 file_info_output)

call write_single_file(state_ens_handle, file_info_input)

call finalize_mpi_utilities()

end program test_write_single_file
