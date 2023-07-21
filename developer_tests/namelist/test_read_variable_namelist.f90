program test_read_variable_namelist

use    utilities_mod, only : find_namelist_in_file, check_namelist_read 
use    mpi_utilities_mod, only : initialize_mpi_utilities,                &
                                 finalize_mpi_utilities
use        types_mod, only : vtablenamelength

implicit none

character(len=vtablenamelength) :: state_variables(20, 3)

integer :: iunit, io

namelist /model_nml/  &
   state_variables

call initialize_mpi_utilities('test_read_write_restarts')

call find_namelist_in_file('input.nml', 'model_nml', iunit)
read(iunit, nml = model_nml, iostat = io)
call check_namelist_read(iunit, io, 'model_nml')

print*, "Hello World!"

call finalize_mpi_utilities()

end program test_read_variable_namelist
