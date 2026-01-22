! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download

!> Tests model_mod routines. Very useful when adding a new model.
!> This version works for models with any location type.
!> Depends on a location-specific module
!> for test_interpolate_single and test_interpolate_range.

program model_mod_check_gc

use             types_mod, only : r8, i8, missing_r8, metadatalength

use         utilities_mod, only : error_handler, E_MSG, E_ERR, &
                                  find_namelist_in_file, check_namelist_read,   &
                                  E_MSG, open_file, close_file, do_output, &
                                  nmlfileunit, get_unit

use     mpi_utilities_mod, only : initialize_mpi_utilities, finalize_mpi_utilities, my_task_id

use          location_mod, only : location_type, write_location, get_close_type, &
                                  get_close_init, VERTISHEIGHT, VERTISLEVEL, VERTISPRESSURE, &
                                  VERTISSCALEHEIGHT, set_location

use          obs_kind_mod, only : get_name_for_quantity

use      obs_sequence_mod, only : static_init_obs_sequence

use       assim_model_mod, only : static_init_assim_model, get_close_state

use      time_manager_mod, only : time_type, print_time, print_date, operator(-), &
                                  get_calendar_type, NO_CALENDAR

use  ensemble_manager_mod, only : init_ensemble_manager, ensemble_type, get_my_num_vars, &
                                  get_my_vars

use   state_vector_io_mod, only : state_vector_io_init, read_state, write_state

use   state_structure_mod, only : get_num_domains, get_model_variable_indices, &
                                  state_structure_info

use      io_filenames_mod, only : io_filenames_init, file_info_type,       &
                                  stage_metadata_type, get_stage_metadata, &
                                  get_restart_filename, set_file_metadata, &
                                  set_io_copy_flag, READ_COPY, WRITE_COPY

use distributed_state_mod, only : create_state_window, free_state_window, &
                                  create_mean_window, free_mean_window

use             model_mod, only : get_model_size, get_state_meta_data, convert_vertical_state, &
                                  convert_vertical_obs

use  test_interpolate_mod, only : test_interpolate_single, &
                                  test_interpolate_range, &
                                  find_closest_gridpoint

implicit none

character(len=*), parameter :: source = 'model_mod_check.f90'

integer, parameter :: MAX_TESTS = 7

! this is max number of domains times number of ensemble members
! if you have more than one domain and your ensemble members are
! in separate files, the names should be listed in this order:
!  all filenames for ensemble members for domain 1
!  all filenames for ensemble members for domain 2, etc

integer, parameter :: MAX_FILES = 1000

!------------------------------------------------------------------
! The namelist variables
!------------------------------------------------------------------

logical                       :: single_file = .false.
integer                       :: num_ens = 1
character(len=256)            :: input_state_files(MAX_FILES)  = 'null'
character(len=256)            :: output_state_files(MAX_FILES) = 'null'
character(len=256)            :: all_metadata_file = 'metadata.txt'
integer(i8)                   :: x_ind   = -1
real(r8), dimension(3)        :: loc_of_interest = -1.0_r8
character(len=metadatalength) :: quantity_of_interest = 'NONE'
character(len=metadatalength) :: interp_test_vertcoord = 'VERTISHEIGHT'
logical                       :: verbose = .FALSE.
integer                       :: test1thru = MAX_TESTS
integer                       :: run_tests(MAX_TESTS) = -1
real(r8)               :: interp_test_dlat  = 10.0_r8
real(r8)               :: interp_test_dlon  = 10.0_r8
real(r8)               :: interp_test_dvert = 10.0_r8
real(r8), dimension(2) :: interp_test_latrange  = (/   0.0_r8,  120.0_r8 /)
real(r8), dimension(2) :: interp_test_lonrange  = (/   0.0_r8,  120.0_r8 /)
real(r8), dimension(2) :: interp_test_vertrange = (/   0.0_r8,  100.0_r8 /)
real(r8)               :: interp_test_dx = missing_r8
real(r8)               :: interp_test_dy = missing_r8
real(r8)               :: interp_test_dz = missing_r8
real(r8), dimension(2) :: interp_test_xrange = (/ missing_r8, missing_r8 /)
real(r8), dimension(2) :: interp_test_yrange = (/ missing_r8, missing_r8 /)
real(r8), dimension(2) :: interp_test_zrange = (/ missing_r8, missing_r8 /)
integer :: vert_coord = VERTISHEIGHT

namelist /model_mod_check_gc_nml/ x_ind, num_ens,                             &
                               loc_of_interest,    quantity_of_interest,   &
                               interp_test_dlat,   interp_test_lonrange,   &
                               interp_test_dlon,   interp_test_latrange,   &
                               interp_test_dvert,  interp_test_vertrange,  &
                               interp_test_dx,     interp_test_xrange,     &
                               interp_test_dy,     interp_test_yrange,     &
                               interp_test_dz,     interp_test_zrange,     &
                               verbose, test1thru, run_tests, interp_test_vertcoord,  &
                               single_file, input_state_files, output_state_files, &
                               all_metadata_file, vert_coord

! io variables
integer                   :: iunit, io
integer, allocatable      :: ios_out(:)
type(file_info_type)      :: file_info_input, file_info_output
type(stage_metadata_type) :: input_restart_files, output_restart_files
logical :: read_time_from_file = .true.
logical :: tests_to_run(MAX_TESTS) = .false.

! model state variables
type(ensemble_type)   :: ens_handle

type(time_type)       :: model_time
integer(i8)           :: model_size
real(r8), allocatable :: interp_vals(:)

! misc. variables
integer :: idom, imem, num_passed, num_failed, num_domains, idomain
logical :: cartesian = .false.

! message strings
character(len=512) :: my_base, my_desc
character(len=512) :: string1, string2, string3

character(len=256), allocatable :: file_array_input(:,:), file_array_output(:,:)
character(len=20) :: task_str

!======================================================================
! start of executable code
!======================================================================

call initialize_modules_used()

call find_namelist_in_file("input.nml", "model_mod_check_gc_nml", iunit)
read(iunit, nml = model_mod_check_gc_nml, iostat = io)
call check_namelist_read(iunit, io, "model_mod_check_gc_nml")

call setup_run_array()
call setup_interp_grid()

!----------------------------------------------------------------------
! Calling static_init_assim_model() is required for all tests.
! It also calls static_init_model(), so there is no need to explicitly call
! that. Furthermore, the low-order models have no check in them to prevent
! static_init_model() from being called twice, so it BOMBS if you call both.
!----------------------------------------------------------------------

call print_test_message('TEST 0', &
         'Reading the model_mod namelist and implicitly running static_init_model', &
         starting=.true.)

call static_init_assim_model()

num_domains = get_num_domains()
model_size = get_model_size()

call print_test_message('TEST 0', ending=.true.)

!----------------------------------------------------------------------
! initialization code, model size
!----------------------------------------------------------------------

if (tests_to_run(1)) then

   call print_test_message('TEST 1', &
            'Verifying composition of the state and calling get_model_size()', &
            starting=.true.)

   if (verbose) then
      string1 = 'To suppress the detailed list of the variables that comprise the DART state'
      string2 = 'set "verbose = .FALSE." in the model_mod_check_nml namelist.'
      call print_info_message(string1, string2)

      do idomain = 1,num_domains
         call state_structure_info(idomain)
      enddo
   else
      string1 = 'To print a detailed list of the variables that comprise the DART state'
      string2 = 'set "verbose = .TRUE." in the model_mod_check_nml namelist.'
      call print_info_message(string1, string2)
   endif

   model_size = get_model_size()
   call left_just_i8(model_size, string3)

   write(string1, *) 'state vector has a length of ', trim(string3)
   call print_info_message(string1)

   call print_test_message('TEST 1', ending=.true.)

endif

!----------------------------------------------------------------------
! read restart files
!----------------------------------------------------------------------

if (tests_to_run(2)) then

   call print_test_message('TEST 2', &
                           'Read and write restart file', starting=.true.)

   ! Set up the ensemble storage and read in the restart file
   call init_ensemble_manager(ens_handle, num_ens, model_size)

   call do_read_test(ens_handle)

   call print_model_time(model_time)
 
   call print_test_message('TEST 2', ending=.true.)

endif

!----------------------------------------------------------------------
! find closest state / convert vertical state
!----------------------------------------------------------------------


call print_test_message('TEST 3', &
                           'Get close state', starting=.true.)

call create_mean_window(ens_handle, 1, distribute_mean=.false.)

call test_get_close_state(ens_handle)

!call test_convert_vertical_state(ens_handle)

!call test_convert_vertical_obs(ens_handle)

call free_mean_window()

call print_test_message('TEST 3', ending=.true.)

!----------------------------------------------------------------------
! finalize model_mod_check
!----------------------------------------------------------------------

call print_info_message('model_mod_check Finished successfully')

call finalize_modules_used()

!======================================================================
contains
!======================================================================

!> initialize modules that need it

subroutine initialize_modules_used()

call initialize_mpi_utilities('model_mod_check')

call static_init_obs_sequence()

call state_vector_io_init()

end subroutine initialize_modules_used

!----------------------------------------------------------------------
subroutine test_convert_vertical_obs(ens_handle)
type(ensemble_type), intent(in) :: ens_handle

! one obs but convert vertical obs is expecting an array
integer :: obs_kind(1)
integer :: obs_type(1)
type(location_type) :: obs_loc(1)
integer :: vstatus(1)
real(r8) :: lon, lat, vert_loc

lon = 1.939
lat = 44.264
!vert_loc = 628.1 ! height in meters
!obs_loc(1) = set_location(lon, lat, vert_loc, VERTISHEIGHT)

!vert_loc = 16.0_r8 ! model level
!obs_loc(1) = set_location(lon, lat, vert_loc, VERTISLEVEL)

vert_loc = 54221.0_r8 ! pressure !HK todo _r8?
obs_loc(1) = set_location(lon, lat, vert_loc, VERTISPRESSURE)

!vert_loc = 0.49_r8 ! scale height
!obs_loc(1) = set_location(lon, lat, vert_loc, VERTISSCALEHEIGHT)



obs_kind(1) = 1 ! dummy for wrf?

print*, 'obs_loc(1) before = ', obs_loc(1)%lon, obs_loc(1)%lat, obs_loc(1)%vloc, obs_loc(1)%which_vert

call convert_vertical_obs(ens_handle, 1, obs_loc, &
                                obs_kind, obs_type, vert_coord, vstatus)

print*, 'convert_vertical_obs status = ', vstatus
print*, 'obs_loc(1) after = ', obs_loc(1)%lon, obs_loc(1)%lat, obs_loc(1)%vloc, obs_loc(1)%which_vert

end subroutine test_convert_vertical_obs

!----------------------------------------------------------------------
subroutine test_convert_vertical_state(ens_handle)

type(ensemble_type), intent(in) :: ens_handle

integer(i8), allocatable :: my_state_indx(:)
type(location_type), allocatable :: my_state_loc(:)
integer, allocatable :: my_state_kind(:)
integer :: i, num_vars
integer :: istatus
character(len=20) :: task_str
integer :: funit
character(len=256) :: filename


num_vars = get_my_num_vars(ens_handle)

allocate(my_state_indx(num_vars))
allocate(my_state_loc(num_vars))
allocate(my_state_kind(num_vars))

call get_my_vars(ens_handle, my_state_indx)

do i=1, num_vars
    call get_state_meta_data(my_state_indx(i), my_state_loc(i), my_state_kind(i))
end do

call convert_vertical_state(ens_handle, num_vars, my_state_loc, my_state_kind,&
   my_state_indx, vert_coord, istatus)


! write the results to a file
funit = get_unit()
write(task_str, '(I4.4)') my_task_id()
filename = 'convert_vertical_state_task_' // trim(task_str)
open(unit=funit, file=filename, status='replace', action='write')
do i = 1, num_vars
    write(funit,*) my_state_indx(i), my_state_loc(i)%lon, my_state_loc(i)%lat, my_state_loc(i)%vloc
end do
write(funit,*) 'Index      Distance'
close(funit)


end subroutine test_convert_vertical_state

!----------------------------------------------------------------------
subroutine test_get_close_state(ens_handle)

type(ensemble_type), intent(in) :: ens_handle

integer(i8), allocatable :: my_state_indx(:)
integer, allocatable :: close_state_ind(:)
real(r8), allocatable :: close_state_dist(:)
integer, allocatable :: my_state_kind(:)
type(location_type), allocatable :: my_state_loc(:)

type(location_type) :: base_obs_loc
integer :: base_obs_type
type(get_close_type) :: gc_state
integer :: i, num_close_states
real(r8) :: cutoff
integer :: num_vars
character(len=256) :: filename
integer :: funit
real(r8) :: lon, lat, vert_loc
integer :: idx 

cutoff = 0.02_r8

num_vars = get_my_num_vars(ens_handle)

allocate(my_state_indx(num_vars))
allocate(my_state_loc(num_vars))
allocate(my_state_kind(num_vars))
allocate(close_state_ind(num_vars))
allocate(close_state_dist(num_vars))

call get_my_vars(ens_handle, my_state_indx)

do i=1, num_vars
    call get_state_meta_data(my_state_indx(i), my_state_loc(i), my_state_kind(i))
end do

call get_close_init(gc_state, num_vars, 2.0_r8*cutoff, my_state_loc)


!base_obs_loc = set_location(0.04_r8, 0.04_r8, 6002.0_r8, VERTISHEIGHT)
!base_obs_loc = set_location(0.04_r8, 0.04_r8, 92728.0_r8, VERTISPRESSURE)

lon = 1.939
lat = 44.264
vert_loc = 628.1 ! height in meters
base_obs_loc = set_location(lon, lat, vert_loc, VERTISHEIGHT)

!vert_loc = 16.0_r8 ! model level
!obs_loc(1) = set_location(lon, lat, vert_loc, VERTISLEVEL)

!vert_loc = 54221.0_r8 ! pressure !HK todo _r8?
!base_obs_loc = set_location(lon, lat, vert_loc, VERTISPRESSURE)


base_obs_type = 1

!call get_close_state(gc_state, base_obs_loc, base_obs_type, &
!                      my_state_loc, my_state_kind, my_state_indx, &
!                      num_close_states, close_state_ind, close_state_dist, ens_handle)

idx = 62
call get_close_state(gc_state, base_obs_loc, base_obs_type, &
                      my_state_loc, my_state_kind, my_state_indx, &
                      num_close_states, close_state_ind, close_state_dist, ens_handle)


! write the results to a file
funit = get_unit()
write(task_str, '(I4.4)') my_task_id()
filename = 'close_state_output_task_' // trim(task_str)
open(unit=funit, file=filename, status='replace', action='write')
write(funit,*) 'base obs loc', base_obs_loc%lon, base_obs_loc%lat, base_obs_loc%vloc, base_obs_loc%which_vert
write(funit,*) 'Number of close states found: ', num_close_states
write(funit,*) 'Cutoff distance: ', cutoff
do i = 1, num_close_states
    write(funit,*) close_state_ind(i), close_state_dist(i)
end do
write(funit,*) 'Index      Distance'
close(funit)

end subroutine test_get_close_state

!----------------------------------------------------------------------
!> clean up before exiting

subroutine finalize_modules_used()

! this must be last, and you can't print/write anything
! after this is called.
call finalize_mpi_utilities()

end subroutine finalize_modules_used

!----------------------------------------------------------------------
!> print the results of get_state_meta_data() at a single location

subroutine check_meta_data( iloc )

integer(i8), intent(in) :: iloc

type(location_type) :: loc
integer             :: ix, iy, iz, dom_id, qty_index, var_type
character(len=256)  :: qty_string

call left_just_i8(iloc, string3)
write(string1, *) 'requesting meta data for state vector index '//trim(string3)
write(string2, *) 'set by namelist item "x_ind"'
call print_info_message(string1, string2)

call get_state_meta_data(iloc, loc, var_type)
call get_model_variable_indices(iloc, ix, iy, iz, &
                                   dom_id=dom_id, &
                                   kind_index=qty_index, &
                                   kind_string=qty_string)

write(string1,'("index ",i11," is i,j,k",3(1x,i10)," and is in domain ",i2)') &
                  iloc, ix, iy, iz, dom_id
write(string2,'("is quantity ", I4,", ",A)') var_type, trim(qty_string)//' at location'
call write_location(0,loc,charstring=string3)

call print_info_message(string1, string2, string3)

end subroutine check_meta_data

!----------------------------------------------------------------------
!> compute the points to be used when testing interpolation

subroutine setup_interp_grid()

if ( interp_test_dx  /= missing_r8 .or. &
     interp_test_dy  /= missing_r8 .or. &
     interp_test_dz  /= missing_r8 ) then

   ! if the user defines cartesian coordinates just
   ! overwrite values for the test_interpolation calls.

   interp_test_dlon  = interp_test_dx
   interp_test_dlat  = interp_test_dy
   interp_test_dvert = interp_test_dz

   interp_test_lonrange  = interp_test_xrange
   interp_test_latrange  = interp_test_yrange
   interp_test_vertrange = interp_test_zrange

   cartesian = .true.
endif

end subroutine setup_interp_grid

!----------------------------------------------------------------------
!> configure the tests to run

!> if they used the existing 'test1thru', use that to select tests 1-N.
!> otherwise:
!> run_tests(:) is initialized to all -1.  if the user didn't set
!> test1thru and if run_tests() is still all -1, turn everything on.
!> otherwise if the first entry isn't -1, they did specify
!> something in that namelist entry and we turn on just those tests.

subroutine setup_run_array()

integer :: i

tests_to_run(:) = .false.

! be backwards compatible - set this to -1 to disable.

if (test1thru > 0) then
   if (test1thru > MAX_TESTS) then
      write(string1, *) 'test1thru must be between 1 and ', MAX_TESTS, '; found value ', test1thru
      call error_handler(E_ERR, 'model_mod_check: setup_run_array', string1, source)
   endif

   tests_to_run(1:test1thru) = .true.
   return
endif

! Enable specific tests.
! the first -1 ends the list.

do i=1, MAX_TESTS
   if (run_tests(i) <= 0) exit

   if (run_tests(i) > MAX_TESTS) then
      write(string1, *) 'test numbers must be between 1 and ', MAX_TESTS, '; found value ', run_tests(i)
      call error_handler(E_ERR, 'model_mod_check: setup_run_array', string1, source)
   endif

   tests_to_run(run_tests(i)) = .true.
enddo

! Make sure they are running something

if (run_tests(1) == -1) then
      write(string1, *) 'No tests selected from the namelist.'
      write(string2, *) 'Either specify "test1thru" to be a positive number - or -'
      write(string3, *) 'specify a list of tests to run in "run_tests".'
      call error_handler(E_ERR, 'model_mod_check: setup_run_array', string1, source, text2=string2, text3=string3)
endif

! enforce and report on unfulfilled dependencies

if ((tests_to_run(4) .or. tests_to_run(5)) .and. .not. tests_to_run(2)) then
   write(string1, *) 'The interpolation tests (Test 4, Test 5) need a model state,'
   write(string2, *) 'so Test 2 must be run.'
   call error_handler(E_MSG, 'model_mod_check: setup_run_array', string1, &
                         text2=string2)
   tests_to_run(2) = .true.
endif

end subroutine setup_run_array

!------------------------------------------------------------------
!> given a default value and an optional value,
!> if the optional value is present return that.
!> otherwise return the default value.

!>@todo this belongs in the utils module, yes?

function set_logical_flag(def_val, user_val)

logical, intent(in)           :: def_val
logical, intent(in), optional :: user_val
logical                       :: set_logical_flag

if (present(user_val)) then
   set_logical_flag = user_val
else
   set_logical_flag = def_val
endif

end function set_logical_flag

!------------------------------------------------------------------
!> report the metadata for every element in the state. This can be
!> very slow but is sometimes useful to determine the exact location
!> for specific indices and to confirm the packing order. 

subroutine check_all_meta_data()

integer(i8)         :: iloc
type(location_type) :: loc
integer             :: ix, iy, iz, dom_id, qty_index, var_type, fid
character(len=256)  :: qty_string, metadata_qty_string

fid = open_file(all_metadata_file)

do iloc = 1,model_size

   call get_model_variable_indices(iloc, ix, iy, iz, &
                                   dom_id=dom_id, &
                                   kind_index=qty_index, &
                                   kind_string=qty_string)

   ! CLM has (potentially many) columns and needs i7 ish precision
!    write(string1,'(i11,1x,''i,j,k'',3(1x,i7),'' domain '',i2)') &
!                   iloc, ix, iy, iz, dom_id
   ! EL: integer to short for the new I/O method
   ! Change to long int to avoid problems
   write(string1,'(i21,1x,''i,j,k'',3(1x,i21),'' domain '',i2)') &
                  iloc, ix, iy, iz, dom_id
   call get_state_meta_data(iloc, loc, var_type)
   metadata_qty_string = trim(get_name_for_quantity(var_type))

   if (trim(qty_string) /= trim(metadata_qty_string) ) then
      write(string2,*)' expected quantity of "'//trim(qty_string)//'"'
      write(string3,*)' got      quantity of "'//trim(metadata_qty_string)//'"'
      call error_handler(E_ERR, 'check_all_meta_data', string1, source, &
                         text2=string2, text3=string3)
   endif

   call write_location(0,loc,charstring=string2)

   write(string3,'(A,1x,I4,1x,A33,1x,A)') &
         trim(string1), var_type, trim(qty_string), trim(string2)

   if ( do_output()                                    ) write(fid,'(A)') trim(string3)
   if ( do_output() .and. mod(iloc,int(100000,i8)) == 0) write( * ,'(A)') trim(string3)

enddo

call close_file(fid)

end subroutine check_all_meta_data

!------------------------------------------------------------------

subroutine do_read_test(ens_handle)

type(ensemble_type), intent(inout) :: ens_handle

! Allocate space for file arrays.  contains a matrix of files (num_ens x num_domains)
! If perturbing from a single instance the number of input files does not have to
! be ens_size but rather a single file (or multiple files if more than one domain)

allocate(file_array_input( num_ens, num_domains))
file_array_input  = RESHAPE(input_state_files,  (/num_ens,  num_domains/))

! Test the read portion.
call io_filenames_init(file_info_input,             &
                       ncopies      = num_ens,      &
                       cycling      = single_file,  &
                       single_file  = single_file,  &
                       restart_files = file_array_input)

do imem = 1, num_ens
   write(my_base,'(A,I2)') 'inens_',    imem
   write(my_desc,'(A,I2)') 'input ens', imem
   call set_file_metadata(file_info_input,                      &
                          cnum     = imem,                      &
                          fnames   = file_array_input(imem,:),  &
                          basename = my_base,                   &
                          desc     = my_desc)

   call set_io_copy_flag(file_info_input,    &
                         cnum    = imem,     &
                         io_flag = READ_COPY)
enddo

input_restart_files = get_stage_metadata(file_info_input)

do idom = 1, num_domains
   do imem = 1, num_ens
      write(string1, *) 'Reading File : ', trim(get_restart_filename(input_restart_files, imem, domain=idom))
      call print_info_message(string1)
   enddo
enddo

call read_state(ens_handle, file_info_input, read_time_from_file, model_time)

deallocate(file_array_input)

end subroutine do_read_test

!------------------------------------------------------------------

subroutine do_write_test(ens_handle)

type(ensemble_type), intent(inout) :: ens_handle

allocate(file_array_output(num_ens, num_domains))
file_array_output = RESHAPE(output_state_files, (/num_ens,  num_domains/))

! Test the write portion.
call io_filenames_init(file_info_output,           &
                       ncopies      = num_ens,     &
                       cycling      = single_file, &
                       single_file  = single_file, &
                       restart_files = file_array_output)

do imem = 1, num_ens
   write(my_base,'(A,I2)') 'outens_',    imem
   write(my_desc,'(A,I2)') 'output ens', imem
   call set_file_metadata(file_info_output,                      &
                          cnum     = imem,                       &
                          fnames   = file_array_output(imem,:),  &
                          basename = my_base,                    &
                          desc     = my_desc)

   call set_io_copy_flag(file_info_output,    &
                         cnum    = imem,      &
                         io_flag = WRITE_COPY)
enddo

output_restart_files = get_stage_metadata(file_info_output)

do idom = 1, num_domains
   do imem = 1, num_ens
      write(string1, *) 'Writing File : ', trim(get_restart_filename(output_restart_files, imem, domain=idom))
      call print_info_message(string1)
   enddo
enddo

call write_state(ens_handle, file_info_output)

deallocate(file_array_output)

end subroutine do_write_test

!------------------------------------------------------------------

subroutine print_model_time(mtime)

type(time_type), intent(in) :: mtime

! this can be an MPI program.  do this only from a single task or you
! get hash from multiple tasks writing over each other.

if (.not. do_output()) return

write(*,'(A)') ''
write(*,'(A)') '-------------------------------------------------------------'

! print date does not work when a model does not have a calendar
if (get_calendar_type() /= NO_CALENDAR) then
   write(*,'(A)') 'printing model date: '
   call print_date( mtime,' model_mod_check:model date')
endif
   
write(*,'(A)') 'printing model time: '
call print_time( mtime,' model_mod_check:model time')
write(*,'(A)') '-------------------------------------------------------------'
write(*,'(A)') ''

end subroutine print_model_time

!----------------------------------------------------------------------
!> print the labels between the starts of tests

subroutine print_test_message(test_label, msg1, msg2, msg3, starting, ending)

character(len=*), intent(in) :: test_label
character(len=*), intent(in), optional :: msg1
character(len=*), intent(in), optional :: msg2
character(len=*), intent(in), optional :: msg3
logical,          intent(in), optional :: starting
logical,          intent(in), optional :: ending

call print_message(.true., test_label, msg1, msg2, msg3, starting, ending)

end subroutine print_test_message

!----------------------------------------------------------------------
!> print an informational message

subroutine print_info_message(info_msg, msg1, msg2, msg3, starting, ending)

character(len=*), intent(in) :: info_msg
character(len=*), intent(in), optional :: msg1
character(len=*), intent(in), optional :: msg2
character(len=*), intent(in), optional :: msg3
logical,          intent(in), optional :: starting
logical,          intent(in), optional :: ending

call print_message(.false., info_msg, msg1, msg2, msg3, starting, ending)

end subroutine print_info_message

!----------------------------------------------------------------------
!> common code for printing

subroutine print_message(is_test_label, msg, msg1, msg2, msg3, starting, ending)

logical,          intent(in) :: is_test_label   ! true is test, false is info
character(len=*), intent(in) :: msg
character(len=*), intent(in), optional :: msg1
character(len=*), intent(in), optional :: msg2
character(len=*), intent(in), optional :: msg3
logical,          intent(in), optional :: starting
logical,          intent(in), optional :: ending

character(len=20) :: test_label
character(len=64) :: msg_label
character(len=64) :: msg_blank
character(len=64) :: msg_close
character(len=64) :: msg_sep1
character(len=64) :: msg_sep2
logical :: is_start, is_end

! if my task isn't writing output, return now.
if (.not. do_output()) return

! setup section - set defaults for optional arguments
! so we don't have to keep testing them.

is_start = set_logical_flag(.false., starting)
is_end   = set_logical_flag(.false., ending)

! is it documented anywhere that this can only be 20 chars long?
! i'm assuming this was set up so the separators would line up.

if (is_test_label) then
   if (is_start) then
      test_label = 'RUNNING    '//trim(msg)
   else if (is_end) then
      test_label = 'FINISHED   '//trim(msg)
   else
      test_label = msg
   endif
   write(msg_label, '(3A)') '***************** ', test_label,     ' ***********************'
endif

write(msg_close ,'(A)' ) '**************************************************************'
write(msg_sep1,  '(A)' ) 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
write(msg_sep2,  '(A)' ) '--------------------------------------------------------------'
write(msg_blank, '(A)' ) ''

! ok, here's where the actual writing happens.
! if you want to change the formatting, fool around with
! the order and formatting of these lines and it will affect
! all the output from this program.

if (is_test_label) then
                      write(*,'(A)') trim(msg_blank)
                      write(*,'(A)') trim(msg_blank)

                      write(*,'(A)') trim(msg_label)
   if (present(msg1)) write(*,'(2A)') ' -- ', trim(msg1)
   if (present(msg2)) write(*,'(2A)') ' -- ', trim(msg2)
   if (present(msg3)) write(*,'(2A)') ' -- ', trim(msg3)
   if (present(msg1)) write(*,'(A)') trim(msg_close)

   if (is_end) then
                      write(*,'(A)') trim(msg_sep1)
                      write(*,'(A)') trim(msg_sep1)
   endif
else  ! info message
                      write(*,'(A)') trim(msg_sep2)
                      write(*,'(A)') trim(msg)
   if (present(msg1)) write(*,'(2A)') ' -- ', trim(msg1)
   if (present(msg2)) write(*,'(2A)') ' -- ', trim(msg2)
   if (present(msg3)) write(*,'(2A)') ' -- ', trim(msg3)
                      write(*,'(A)') trim(msg_sep2)
endif

end subroutine print_message

!------------------------------------------------------------------

subroutine left_just_i8(ivalue, ostring)
integer(i8),      intent(in)  :: ivalue
character(len=*), intent(out) :: ostring

write(ostring, *)  ivalue
ostring = adjustl(ostring)

end subroutine left_just_i8

!------------------------------------------------------------------

end program model_mod_check_gc

