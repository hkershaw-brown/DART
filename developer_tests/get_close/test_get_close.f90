! Aim: Test harness for get_close_obs 3D sphere
!      Create a bunch of observations, find the close ones
!
! get_close is used for both observations and state elements (X,Y,Z,variable)
! get_close is called in filter_assim_mod
!
! Psuedo code for filter assim
! ---
!  initialize get_close (state)
!  initialize get_close (obs)
!
!  ! Loop through all the (global) observations sequentially
!  SEQUENTIAL_OBS do i = 1, total number of observations
!   
!      calculate increments for this observation
!
!      call get_close_state (state)
!      update close states 
!
!      call get_close_obs (obs)
!      update observations that have not already been assimilated
!
!   end do SEQUENTIAL_OBS
! ---
!
! There are separate calls for get_close_obs and get_close_state because
! the model can intercept these calls and choose to alter the distance
! calculation. This test program calls the location_mod directory
! Using 3D sphere location mod as this is the most commonly used.
!
program test_get_close_obs

use location_mod,         only : location_type, get_close_type, get_close_obs, get_close_init, &
                                 VERTISUNDEF, set_location, get_close_init, get_close_destroy, &
                                 VERTISHEIGHT
use types_mod,            only : r8, MISSING_R8, PI
use ensemble_manager_mod, only : ensemble_type, get_my_vars, get_my_num_vars, init_ensemble_manager 
use mpi_utilities_mod,    only : initialize_mpi_utilities, finalize_mpi_utilities, my_task_id
use random_seq_mod,       only : init_random_seq, random_uniform, random_seq_type
use utilities_mod,        only : nmlfileunit, find_namelist_in_file, check_namelist_read, open_file

use mpi 

implicit none

integer :: arg_count, arg_len, stat
character(len=32) :: arg_val

type(get_close_type)              :: gc_obs
type(location_type)               :: base_obs_loc
type(location_type), allocatable  :: my_obs_loc(:)

type(random_seq_type) :: r
real(r8)              :: x, y, z ! random numbers

integer,  allocatable :: my_obs_kind(:) !< physical qty of ob, e.g. temperature
integer,  allocatable :: my_obs_type(:) !< types of ob, e.g. radiosonde
real(r8), allocatable :: close_obs_dist(:)
integer,  allocatable :: close_obs_ind(:)
integer               :: base_obs_type
integer               :: num_close_obs
integer               :: i, obs !< loop variables
real(r8)              :: vert_loc !< vertical location - ignoring this for now
integer               :: which_vert !< vertical location - ignoring this for now
real(r8)              :: lon !< longitude
real(r8)              :: lat !< latitude

double precision   :: start !< for timing


! Default values
integer  :: my_num_obs  = 100 !< number of observations my processor owns
integer  :: obs_to_assimilate = 1000  !< number of observations being assimilated
integer  :: num_repeats = 1 !< how many times to run get_close_obs
integer  :: lon_start   = 0 !< longitude boundary
integer  :: lon_end     = 359 !< longitude boundary
integer  :: lat_start   = -80 !< latitude boundary
integer  :: lat_end     = 80 !< latitude boundary
real(r8) :: cutoff      = 0.15 !< cutoff in radians 

call initialize_mpi_utilities('test_get_close') ! only have mpi for mpi_wtime

! Parse command line argument for my_num_obs (first argument)
call get_command_argument(1, arg_val, status=stat)
if (stat == 0) then
   read(arg_val, *, iostat=stat) my_num_obs
   if (stat /= 0) then
      if (my_task_id() == 0) print *, 'Invalid my_num_obs argument, using default:', my_num_obs
   endif
else
   if (my_task_id() == 0) print *, 'No my_num_obs argument provided, using default:', my_num_obs
endif

if (my_task_id() == 0) then
   print*, 'num_obs', my_num_obs
   print*, 'lon_start', lon_start
   print*, 'lon_end', lon_end
   print*, 'lat_start', lat_start
   print*, 'lat_end', lat_end
   print*, 'cutoff', cutoff
endif

! -------  pick the base obs -------
! In an assimilation the base_obs_loc would be different for 
! each step of obs_to_assimilate loop
base_obs_loc = set_location(250.5818377_r8, 40.63913947_r8, 695.28760_r8, VERTISHEIGHT) 

call init_random_seq(r, my_task_id()) ! for randomly generated obs locations

! Currently set to 2D distance
! &location_nml
!   horiz_dist_only                 = .true.,

! other obs location 2D
which_vert = VERTISUNDEF
vert_loc = 0

! set up arrays
allocate(my_obs_loc(my_num_obs), my_obs_kind(my_num_obs), my_obs_type(my_num_obs))
allocate(close_obs_dist(my_num_obs), close_obs_ind(my_num_obs))

! fill observation locations
do i = 1, my_num_obs
   x = random_uniform(r)
   y = random_uniform(r)
   z = random_uniform(r)
   lon = x*(lon_end - lon_start) + lon_start
   lat = y*(lat_end - lat_start) + lat_start
   my_obs_loc(i) = set_location(lon, lat, vert_loc, which_vert)
   my_obs_kind(i) = 1
enddo

start = mpi_wtime()
base_obs_type = 1   ! guaranteed to exist

do i = 1, num_repeats

   ! set up close_obs structure
   ! cufoff_list is multiple radii
   !call get_close_init(gc_gc, my_num_obs, 2.0_r8*cutoff, my_state_loc, 2.0_r8*cutoff_list)
   call get_close_init(gc_obs, my_num_obs, 2.0_r8*cutoff, my_obs_loc)

   do obs = 1, obs_to_assimilate
     ! Note filter assim caches results if (obs location == previous obs location) if cutoff_list is not used
     call get_close_obs(gc_obs, base_obs_loc, base_obs_type, my_obs_loc, &
                     my_obs_kind, my_obs_type, num_close_obs, close_obs_ind)
   enddo

   call get_close_destroy(gc_obs) ! destroy structure

enddo

if(my_task_id()==0) then
   print*, 'Time for ', num_repeats, 'repeats  of get_close_obs for ', obs_to_assimilate, &
            'assimilation steps', mpi_wtime() - start
   print*, 'Time per get_close_obs', (mpi_wtime() - start) / num_repeats
   write(0,*) my_num_obs, (mpi_wtime() - start) / num_repeats
endif


deallocate(my_obs_loc, my_obs_kind, my_obs_type, close_obs_dist, close_obs_ind)

call finalize_mpi_utilities()

end program test_get_close_obs
