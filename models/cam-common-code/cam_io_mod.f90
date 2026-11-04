module cam_io_mod

! CAM specific netCDF output: the grid attributes written to the DART
! diagnostic files, and reading/writing the CAM model time.
! No module-level state; the grid and options are passed in.

use types_mod,            only : r8
use utilities_mod,        only : E_ERR, E_MSG, error_handler, file_exist
use time_manager_mod,     only : time_type, get_date, set_date
use cam_grid_mod,         only : cam_grid
use netcdf_utilities_mod, only : nc_open_file_readonly, nc_close_file, nc_get_variable, &
                                 nc_variable_exists, nc_add_attribute_to_variable, &
                                 nc_define_integer_variable, nc_define_real_variable, &
                                 nc_define_real_scalar, nc_add_global_creation_time, &
                                 nc_add_global_attribute, nc_define_dimension, nc_put_variable, &
                                 nc_synchronize_file, nc_end_define_mode, nc_begin_define_mode

implicit none
private

public :: nc_write_cam_atts, write_model_time, read_model_time

! version controlled file description for error handling, do not edit
character(len=*), parameter :: source   = 'cam_io_mod.f90'
character(len=*), parameter :: revision = ''
character(len=*), parameter :: revdate  = ''

contains

!-----------------------------------------------------------------------
!>
!> Writes the model-specific attributes to a DART 'diagnostic' netCDF file.
!> This includes coordinate variables and some metadata, but NOT the
!> actual DART state.
!>
!> @param ncid       the netCDF handle of the DART diagnostic file opened by
!>                   assim_model_mod:init_diag_output
!> @param grid_data  the CAM grid to write
!> @param suppress_grid_info_in_output  only write the state data, no grid

subroutine nc_write_cam_atts(ncid, grid_data, suppress_grid_info_in_output)

integer,        intent(in) :: ncid      ! netCDF file identifier
type(cam_grid), intent(in) :: grid_data ! the grid to describe in the file
logical,        intent(in) :: suppress_grid_info_in_output

!----------------------------------------------------------------------
! local variables
!----------------------------------------------------------------------

character(len=*), parameter :: routine = 'nc_write_model_atts'

!-------------------------------------------------------------------------------
! Write Global Attributes
!-------------------------------------------------------------------------------

call nc_begin_define_mode(ncid, routine)

call nc_add_global_creation_time(ncid, routine)

call nc_add_global_attribute(ncid, "model_source", source, routine)
call nc_add_global_attribute(ncid, "model_revision", revision, routine)
call nc_add_global_attribute(ncid, "model_revdate", revdate, routine)

call nc_add_global_attribute(ncid, "model", "CAM", routine)

! this option is for users who want the smallest output
! or diagnostic files - only the state vector data will
! be written.   otherwise, if you want to plot this data
! the rest of this routine writes out enough grid info
! to make the output file look like the input.
if (suppress_grid_info_in_output) then
   call nc_end_define_mode(ncid, routine)
   return
endif

!----------------------------------------------------------------------------
! Output the grid variables.
!----------------------------------------------------------------------------
! Define the new dimensions IDs
!----------------------------------------------------------------------------

call nc_define_dimension(ncid, 'lon',  grid_data%lon%nsize,  routine)
call nc_define_dimension(ncid, 'lat',  grid_data%lat%nsize,  routine)
call nc_define_dimension(ncid, 'lev',  grid_data%lev%nsize,  routine)
call nc_define_dimension(ncid, 'ilev', grid_data%ilev%nsize, routine)
call nc_define_dimension(ncid, 'hyam', grid_data%hyam%nsize, routine)
call nc_define_dimension(ncid, 'hybm', grid_data%hybm%nsize, routine)
call nc_define_dimension(ncid, 'hyai', grid_data%hyai%nsize, routine)
call nc_define_dimension(ncid, 'hybi', grid_data%hybi%nsize, routine)

! cam-fv only variables
if(grid_data%slon%nsize > 0) call nc_define_dimension(ncid, 'slon', grid_data%slon%nsize, routine)
if(grid_data%slat%nsize > 0) call nc_define_dimension(ncid, 'slat', grid_data%slat%nsize, routine)
if(grid_data%gw%nsize > 0)   call nc_define_dimension(ncid, 'gw',   grid_data%gw%nsize,   routine)

!----------------------------------------------------------------------------
! Create the Coordinate Variables and the Attributes
! The contents will be written in a later block of code.
!----------------------------------------------------------------------------

! U,V Grid Longitudes
call nc_define_real_variable(     ncid, 'lon', (/ 'lon' /),                 routine)
call nc_add_attribute_to_variable(ncid, 'lon', 'long_name', 'longitude',    routine)
call nc_add_attribute_to_variable(ncid, 'lon', 'units',     'degrees_east', routine)

! U,V Grid Latitudes
call nc_define_real_variable(     ncid, 'lat', (/ 'lat' /),                  routine)
call nc_add_attribute_to_variable(ncid, 'lat', 'long_name', 'latitude',      routine)
call nc_add_attribute_to_variable(ncid, 'lat', 'units',     'degrees_north', routine)

! Vertical Grid Latitudes
call nc_define_real_variable(     ncid, 'lev', (/ 'lev' /),                                                     routine)
call nc_add_attribute_to_variable(ncid, 'lev', 'long_name',      'hybrid level at midpoints (1000*(A+B))',      routine)
call nc_add_attribute_to_variable(ncid, 'lev', 'units',          'hPa',                                         routine)
call nc_add_attribute_to_variable(ncid, 'lev', 'positive',       'down',                                        routine)
call nc_add_attribute_to_variable(ncid, 'lev', 'standard_name',  'atmosphere_hybrid_sigma_pressure_coordinate', routine)
call nc_add_attribute_to_variable(ncid, 'lev', 'formula_terms',  'a: hyam b: hybm p0: P0 ps: PS',               routine)


call nc_define_real_variable(     ncid, 'ilev', (/ 'ilev' /),                                                    routine)
call nc_add_attribute_to_variable(ncid, 'ilev', 'long_name',      'hybrid level at interfaces (1000*(A+B))',     routine)
call nc_add_attribute_to_variable(ncid, 'ilev', 'units',          'hPa',                                         routine)
call nc_add_attribute_to_variable(ncid, 'ilev', 'positive',       'down',                                        routine)
call nc_add_attribute_to_variable(ncid, 'ilev', 'standard_name',  'atmosphere_hybrid_sigma_pressure_coordinate', routine)
call nc_add_attribute_to_variable(ncid, 'ilev', 'formula_terms',  'a: hyai b: hybi p0: P0 ps: PS',               routine)

! Hybrid Coefficients
call nc_define_real_variable(     ncid, 'hyam', (/ 'lev' /),                                            routine)
call nc_add_attribute_to_variable(ncid, 'hyam', 'long_name', 'hybrid A coefficient at layer midpoints', routine)

call nc_define_real_variable(     ncid, 'hybm', (/ 'lev' /),                                            routine)
call nc_add_attribute_to_variable(ncid, 'hybm', 'long_name', 'hybrid B coefficient at layer midpoints', routine)


call nc_define_real_variable(     ncid, 'hyai', (/ 'ilev' /),                                            routine)
call nc_add_attribute_to_variable(ncid, 'hyai', 'long_name', 'hybrid A coefficient at layer interfaces', routine)


call nc_define_real_variable(     ncid, 'hybi', (/ 'ilev' /),                                            routine)
call nc_add_attribute_to_variable(ncid, 'hybi', 'long_name', 'hybrid B coefficient at layer interfaces', routine)

call nc_define_real_scalar(       ncid, 'P0', routine)
call nc_add_attribute_to_variable(ncid, 'P0', 'long_name', 'reference pressure', routine)
call nc_add_attribute_to_variable(ncid, 'P0', 'units',     'Pa',                 routine)

! FV only variables
if(grid_data%slon%nsize > 0) then
   call nc_define_real_variable(     ncid, 'slon', (/ 'slon' /),                       routine)
   call nc_add_attribute_to_variable(ncid, 'slon', 'long_name', 'staggered longitude', routine)
   call nc_add_attribute_to_variable(ncid, 'slon', 'units',     'degrees_east',        routine)
endif
if(grid_data%slat%nsize > 0) then
   call nc_define_real_variable(     ncid, 'slat', (/ 'slat' /),                      routine)
   call nc_add_attribute_to_variable(ncid, 'slat', 'long_name', 'staggered latitude', routine)
   call nc_add_attribute_to_variable(ncid, 'slat', 'units',     'degrees_north',      routine)
endif
if(grid_data%gw%nsize > 0) then
   ! Gaussian Weights
   call nc_define_real_variable(     ncid, 'gw', (/ 'lat' /),                  routine)
   call nc_add_attribute_to_variable(ncid, 'gw', 'long_name', 'gauss weights', routine)
endif

! Finished with dimension/variable definitions, must end 'define' mode to fill.

call nc_end_define_mode(ncid, routine)

!----------------------------------------------------------------------------
! Fill the coordinate variables
!----------------------------------------------------------------------------



call nc_put_variable(ncid, 'lon',  grid_data%lon%vals,  routine)
call nc_put_variable(ncid, 'lat',  grid_data%lat%vals,  routine)
call nc_put_variable(ncid, 'lev',  grid_data%lev%vals,  routine)
call nc_put_variable(ncid, 'ilev', grid_data%ilev%vals, routine)
call nc_put_variable(ncid, 'hyam', grid_data%hyam%vals, routine)
call nc_put_variable(ncid, 'hybm', grid_data%hybm%vals, routine)
call nc_put_variable(ncid, 'hyai', grid_data%hyai%vals, routine)
call nc_put_variable(ncid, 'hybi', grid_data%hybi%vals, routine)
call nc_put_variable(ncid, 'P0',   grid_data%P0%vals,   routine)

!SENote: all the staggered stuff is gone for SE
if(grid_data%slon%nsize > 0) call nc_put_variable(ncid, 'slon', grid_data%slon%vals, routine)
if(grid_data%slat%nsize > 0) call nc_put_variable(ncid, 'slat', grid_data%slat%vals, routine)
if(grid_data%gw%nsize > 0)   call nc_put_variable(ncid, 'gw',   grid_data%gw%vals,   routine)

! flush any pending i/o to disk
call nc_synchronize_file(ncid, routine)

end subroutine nc_write_cam_atts

!-----------------------------------------------------------------------
!> writes CAM's model date and time of day into file.  CAM uses
!> integer date values and integer time of day measured in seconds
!>
!> @param ncid         name of the file
!> @param model_time   the current time of the model state
!>

subroutine write_model_time(ncid, model_time)
integer,         intent(in) :: ncid
type(time_type), intent(in) :: model_time

integer :: iyear, imonth, iday, ihour, iminute, isecond
integer :: cam_date(1), cam_tod(1)

character(len=*), parameter :: routine = 'write_model_time'

!SENote: this used to have a test for initialized, but it's not useful to get
! here without already being initialized
!if ( .not. module_initialized ) call static_init_model

call get_date(model_time, iyear, imonth, iday, ihour, iminute, isecond)

cam_date = iyear*10000 + imonth*100 + iday
cam_tod  = ihour*3600  + iminute*60 + isecond

! if the file doesn't already have a "date" variable make one
if (.not. nc_variable_exists(ncid, "date")) then
   call nc_begin_define_mode(ncid, routine)
   call nc_define_integer_variable(ncid, 'date', (/ 'time' /), routine)
   call nc_end_define_mode(ncid, routine)
   call nc_put_variable(ncid, 'date', cam_date, routine)
endif

! if the file doesn't already have a "datesec" variable make one
if (.not. nc_variable_exists(ncid, "datesec")) then
   call nc_begin_define_mode(ncid, routine)
   call nc_define_integer_variable(ncid, 'datesec', (/ 'time' /), routine)
   call nc_end_define_mode(ncid, routine)
   call nc_put_variable(ncid, 'datesec', cam_tod,  routine)
endif

end subroutine write_model_time

!--------------------------------------------------------------------
!>
!> Read the time from the input file
!>
!> @param filename name of file that contains the time
!>

function read_model_time(filename)

character(len=*), intent(in) :: filename
type(time_type)              :: read_model_time

integer :: ncid
integer :: cam_date, cam_tod
integer :: iyear, imonth, iday, ihour, imin, isec, rem

character(len=*), parameter :: routine = 'read_model_time'
character(len=512) :: string1, string2

!SENote: Doesn't actually need model to be initialized 
!if ( .not. module_initialized ) call static_init_model

if ( .not. file_exist(filename) ) then
   write(string1,*) trim(filename), ' does not exist.'
   call error_handler(E_ERR,routine,string1,source,revision,revdate)
endif

ncid = nc_open_file_readonly(filename, routine)

! CAM initial files have two variables of length 
! 'time' (the unlimited dimension): date, datesec

call nc_get_variable(ncid, 'date',    cam_date, routine)
call nc_get_variable(ncid, 'datesec', cam_tod,  routine)

! 'date' is YYYYMMDD 
! 'cam_tod' is seconds of current day
iyear  = cam_date / 10000
rem    = cam_date - iyear*10000
imonth = rem / 100
iday   = rem - imonth*100

ihour  = cam_tod / 3600
rem    = cam_tod - ihour*3600
imin   = rem / 60
isec   = rem - imin*60

! some cam files are from before the start of the gregorian calendar.
! since these are 'arbitrary' years, just change the offset.
if (iyear < 1601) then
   write(string1,*)' '
   write(string2,*)'WARNING - ',trim(filename),' changing year from ', &
                   iyear,'to',iyear+1601

   call error_handler(E_MSG, routine, string1, source, revision, &
                      revdate, text2=string2,text3='to make it a valid Gregorian date.')

   write(string1,*)' '
   call error_handler(E_MSG, routine, string1, source, revision)
   iyear = iyear + 1601
endif

read_model_time = set_date(iyear,imonth,iday,ihour,imin,isec)

call nc_close_file(ncid, routine)

end function read_model_time

end module cam_io_mod
