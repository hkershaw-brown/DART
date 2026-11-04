module cam_grid_mod

! The CAM grid: the 1d coordinate arrays read from a CAM template file plus
! the few reference values derived from them.  Reading the grid fills a
! cam_grid object owned by the caller; there is no module-level copy.
! Depends only on types_mod, utilities_mod and netcdf_utilities_mod.

use types_mod,          only : MISSING_R8, r8
use utilities_mod,      only : array_dump
use netcdf_utilities_mod, only : nc_open_file_readonly, nc_close_file, nc_get_variable, &
                                 nc_get_variable_size, nc_variable_exists

implicit none
private

public :: cam_1d_array, cam_grid, read_grid_info, free_cam_grid, init_grid_refs

! version controlled file description for error handling, do not edit
character(len=*), parameter :: source   = 'cam_grid_mod.f90'
character(len=*), parameter :: revision = ''
character(len=*), parameter :: revdate  = ''

!> Metadata from the template netCDF file that describes
!> where the variable data is located and what size it is.
type cam_1d_array
   integer  :: nsize
   real(r8), allocatable :: vals(:)
end type

! Note that the cam_grid type contains information about staggered grids that are only for FV
type cam_grid
   type(cam_1d_array) :: lon
   type(cam_1d_array) :: lat
   type(cam_1d_array) :: slon
   type(cam_1d_array) :: slat
   type(cam_1d_array) :: lev
   type(cam_1d_array) :: ilev
   type(cam_1d_array) :: gw
   type(cam_1d_array) :: hyai
   type(cam_1d_array) :: hybi
   type(cam_1d_array) :: hyam
   type(cam_1d_array) :: hybm
   type(cam_1d_array) :: P0

   ! commonly used numbers derived from the arrays above.
   ! set by init_grid_refs (called from read_grid_info).
   real(r8) :: ref_model_top_pressure = MISSING_R8
   real(r8) :: ref_surface_pressure   = MISSING_R8
   integer  :: ref_nlevels            = 0
end type

contains

!-----------------------------------------------------------------------
!> Read in the grid information from the given CAM restart file.
!> Note that none of the data will be used from this file; just the
!> grid size and locations.
!>
!> debug_level > 80 dumps each array that is read.

subroutine read_grid_info(grid_file, grid, debug_level)
character(len=*), intent(in)    :: grid_file   ! cam template file
type(cam_grid),   intent(inout) :: grid
integer,          intent(in)    :: debug_level

! Get the grid info plus additional non-state arrays
call get_cam_grid(grid_file, grid, debug_level)

! and the values derived from them
call init_grid_refs(grid)

end subroutine read_grid_info

!----------------------------------------------------------------------------

!> set values that are used by many routines here and which do not
!> change during the execution of filter.

subroutine init_grid_refs(grid)
type(cam_grid), intent(inout) :: grid

grid%ref_surface_pressure   = grid%P0%vals(1)
grid%ref_model_top_pressure = grid%hyai%vals(1) * grid%ref_surface_pressure
grid%ref_nlevels            = grid%lev%nsize

end subroutine init_grid_refs

!-----------------------------------------------------------------------
!> Read the data from the various cam grid arrays 
!>
!>@todo FIXME not all of these are used.  can we either
!> not read them in, or make them optional?  this does affect
!> what we can write out in the diagnostic file.  if we have
!> to have them in the diag files then we have to read them all
!> even if we never use them.  both ilev and gw currently fall
!> into this category.
!> 

subroutine get_cam_grid(grid_file, grid_data, debug_level)
character(len=*), intent(in)    :: grid_file
type(cam_grid),   intent(inout) :: grid_data
integer,          intent(in)    :: debug_level

character(len=*), parameter :: routine = 'get_cam_grid:'

integer :: ncid

! put this in a subroutine that deals with the grid
ncid = nc_open_file_readonly(grid_file, routine)

call fill_cam_1d_array(ncid, 'lon',  grid_data%lon, debug_level)
call fill_cam_1d_array(ncid, 'lat',  grid_data%lat, debug_level)
call fill_cam_1d_array(ncid, 'lev',  grid_data%lev, debug_level)
call fill_cam_1d_array(ncid, 'ilev', grid_data%ilev, debug_level) ! for staggered vertical grid
call fill_cam_1d_array(ncid, 'slon', grid_data%slon, debug_level)
call fill_cam_1d_array(ncid, 'slat', grid_data%slat, debug_level)
call fill_cam_1d_array(ncid, 'gw',   grid_data%gw, debug_level)   ! gauss weights
call fill_cam_1d_array(ncid, 'hyai', grid_data%hyai, debug_level)
call fill_cam_1d_array(ncid, 'hybi', grid_data%hybi, debug_level)
call fill_cam_1d_array(ncid, 'hyam', grid_data%hyam, debug_level)
call fill_cam_1d_array(ncid, 'hybm', grid_data%hybm, debug_level)

! P0 is a scalar with no dimensionality
call fill_cam_0d_array(ncid, 'P0',   grid_data%P0, debug_level)

call nc_close_file(ncid, routine)

end subroutine get_cam_grid

!-----------------------------------------------------------------------
!>
!> allocate space for a scalar variable and read values into the grid_array
!>   


subroutine fill_cam_1d_array(ncid, varname, grid_array, debug_level)
integer,            intent(in)    :: ncid
character(len=*),   intent(in)    :: varname
type(cam_1d_array), intent(inout) :: grid_array
integer,            intent(in)    :: debug_level

character(len=*), parameter :: routine = 'fill_cam_1d_array'

! SENote: For the SE core, three of these don't exist (gw, slon, slat) so need to check

if(nc_variable_exists(ncid, varname)) then

   call nc_get_variable_size(ncid, varname, grid_array%nsize)
   allocate(grid_array%vals(grid_array%nsize))

   call nc_get_variable(ncid, varname, grid_array%vals, routine)
   
   if (debug_level > 80) call array_dump(grid_array%vals, label=varname)

!SENote: this is the else statement to create something for the slon, slat, and gw fields that aren't used in SE CORE
else
   allocate(grid_array%vals(1))
   grid_array%nsize = -1 ! so you can test before writing
   grid_array%vals(1) = MISSING_R8
endif

end subroutine fill_cam_1d_array

!-----------------------------------------------------------------------
!>
!> free space in the various grid arrays
!> 

subroutine free_cam_grid(grid)

type(cam_grid), intent(inout) :: grid

call free_cam_1d_array(grid%lon)
call free_cam_1d_array(grid%lat)
call free_cam_1d_array(grid%lev)
call free_cam_1d_array(grid%ilev)
call free_cam_1d_array(grid%slon)
call free_cam_1d_array(grid%slat)
call free_cam_1d_array(grid%gw)
call free_cam_1d_array(grid%hyai)
call free_cam_1d_array(grid%hybi)
call free_cam_1d_array(grid%hyam)
call free_cam_1d_array(grid%hybm)
call free_cam_1d_array(grid%P0)

end subroutine free_cam_grid

!-----------------------------------------------------------------------
!>

subroutine free_cam_1d_array(grid_array)
type(cam_1d_array), intent(inout) :: grid_array

deallocate(grid_array%vals)
grid_array%nsize = -1

end subroutine free_cam_1d_array

!-----------------------------------------------------------------------
!>
!> allocate space for a scalar variable and read values into the grid_array
!>   

subroutine fill_cam_0d_array(ncid, varname, grid_array, debug_level)
integer,            intent(in)    :: ncid
character(len=*),   intent(in)    :: varname
type(cam_1d_array), intent(inout) :: grid_array
integer,            intent(in)    :: debug_level

character(len=*), parameter :: routine = 'fill_cam_0d_array'

grid_array%nsize = 1
allocate(grid_array%vals(grid_array%nsize))

!SENOte WARNING: This is the issue with P0 not being in the SE restart files. For now, if it is not in the file
! set to 100000, the value from standard FV files. NEED TO CLARIFY THIS WITH PETER LAURITZEN.
! CGD notes that P0 was removed and Ptop is only in history files, so no alternative for now.
if(varname == 'P0') then
   ! See if PO exists in the netcdf file
   ! NOTE: this tests for 'PO' (letter O), not 'P0' (zero).  That has always been
   ! the case, so P0 is in practice always set to 100000 here.  Left as is to
   ! keep results unchanged; see the refactor notes.
   if(.not. nc_variable_exists(ncid, 'PO')) then
      grid_array%vals(1) = 100000
      return   
   endif
endif 

call nc_get_variable(ncid, varname, grid_array%vals, routine)

if (debug_level > 80) print*, 'variable name ', trim(varname), grid_array%vals

end subroutine fill_cam_0d_array

end module cam_grid_mod
