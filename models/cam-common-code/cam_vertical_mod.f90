module cam_vertical_mod

! Pure vertical-coordinate math for CAM-like hybrid sigma-pressure atmospheres.
!
! Nothing in this module holds mutable state or knows about the model_mod,
! the namelist, the state structure, MPI or netCDF.  Everything it needs
! (reference pressure, hybrid coefficients, log-scale choice, ...) is passed
! in by the caller so each routine can be unit tested in isolation.
! The only dependencies are types_mod and utilities_mod.

use types_mod,     only : MISSING_R8, MISSING_I, r8, DEG2RAD
use utilities_mod, only : E_ERR, error_handler, find_enclosing_indices

implicit none
private

public :: build_heights, gph2gmh, compute_surface_gravity, vert_interp, &
          check_good_levels, height_to_level, pressure_to_level, &
          build_cam_pressure_columns, single_pressure_column, scale_height, &
          std_atm_table_type, init_std_atm_table, free_std_atm_table, &
          std_atm_pressure_to_height, std_atm_height_to_pressure, &
          HIGH_TOP_TABLE, LOW_TOP_TABLE

! version controlled file description for error handling, do not edit
character(len=*), parameter :: source   = 'cam_vertical_mod.f90'
character(len=*), parameter :: revision = ''
character(len=*), parameter :: revdate  = ''

!>@todo FIXME ask kevin if this threshold value is small enough
! to distinguish cam from waccm configurations?

! an arbitrary value to test the model top against to see
! if we're running cam vs waccm or waccm-x.  it changes the
! standard atmosphere table we use to convert pressure to height,
! and changes the formatting of numbers in dart_log output.
real(r8), parameter :: high_top_threshold = 0.3_r8  ! pascals

integer, parameter :: HIGH_TOP_TABLE = 1
integer, parameter :: LOW_TOP_TABLE  = 2

!> A pressure <-> height map based on either a low-top or high-top
!> standard atmosphere, depending on the model top.  Used only to discard
!> obs on heights above the user-defined top threshold.  The caller owns
!> the table; there is no hidden module copy.
type std_atm_table_type
   integer               :: table_kind = -1
   integer               :: len = 0
   real(r8), allocatable :: hgt(:)
   real(r8), allocatable :: pres(:)
end type

contains

!-----------------------------------------------------------------------
!> This code is using a finite difference method to evaluate an 
!> integral to solve the hydrostatic equation. 
!>
!> The details are in the reference given below.
!> Don't change this code until you have read the paper and
!> understand what they're doing.  The paper uses a matrix
!> while this code gets away with ignoring 'l' and evaluating
!> the 'k' vector directly. 
!>
!> Equation references are to "Hybrid Coordinates for CCM1"
!>    https://opensky.ucar.edu/islandora/object/technotes%3A149/datastream/PDF/view
!>
!> Here is a comment from the NCL function that does the
!> same thing for them.
!>
!> Purpose:
!>   To compute geopotential height using the CCM2 hybrid coordinate
!>   vertical slice.  Since the vertical integration matrix is a
!>   function of latitude and longitude, it is not explicitly
!>   computed as for sigma coordinates.  The integration algorithm
!>   is derived from Boville's mods in the ibm file hybrid 1mods
!>   (6/17/88).  All vertical slice arrays are oriented top to
!>   bottom as in CCM2.  This field is on full model levels (aka
!>   "midpoints") not half levels.
!>
!> careful - if the calling code passes in the mbar() parameter a different gas
!>           constant is used instead.  an mbar() array of 1.0 is not the same 
!>           as no parameter specified.

subroutine build_heights(nlevels, p_surf, h_surf, hybi_bottom, pressure, virtual_temp,height_midpts,height_interf,mbar)

integer,  intent(in)  :: nlevels                            ! Number of vertical levels
real(r8), intent(in)  :: p_surf                             ! Surface pressure (pascals)
real(r8), intent(in)  :: h_surf                             ! Surface height (m)
real(r8), intent(in)  :: hybi_bottom                        ! hybi at the lowest interface (must be 1)
real(r8), intent(in)  :: pressure( nlevels)                 ! Pressure
real(r8), intent(in)  :: virtual_temp( nlevels)             ! Virtual Temperature
real(r8), intent(out) :: height_midpts(nlevels)             ! Geopotential height at midpoints, top to bottom
real(r8), intent(out), optional :: height_interf(nlevels+1) ! Geopotential height at interfaces, top to bottom
real(r8), intent(in),  optional :: mbar(nlevels)            ! Factor to support for variable gas constant

! Local variables
!>@todo FIXME can we use the types_mod values here?  or have a model constants module?
real(r8), parameter :: const_r = 287.04_r8    ! Different than model_heights (dry air gas constant)
real(r8), parameter :: universal_gas_constant = 8314.0_r8 ! [J/K/kmol]
real(r8), parameter :: g0 = 9.80616_r8        ! Different than model_heights (gph2gmh:G) !

integer  :: k,l

! an array now: real(r8), parameter :: rbyg=r/g0
real(r8) :: pterm(nlevels)   ! vertical scratch space, to improve computational efficiency
real(r8) :: r_g0_tv(nlevels) ! rbyg=r/g0 * tv
real(r8) :: pm_ln(nlevels+1) ! logs of midpoint pressures plus surface interface pressure

! cam uses a uniform gas constant value, but high top
! models like waccm change the gas constant with height.
! allow for the calling code to pass in an array of r.

! if mbar() array is present notice that the units are different
! for the gas constants, so an mbar() array of 1.0s will NOT give
! the same results as if it isn't present.

if (present(mbar)) then
   r_g0_tv(:) = (universal_gas_constant / (mbar(:)*g0)) * virtual_temp(:)
else
   r_g0_tv(:) = (const_r / g0) * virtual_temp(:)
endif

! calculate the log of the pressure column midpoints.
! items 1:nlevels are the midpoints, but NOTICE THAT
! the pressure at nlevels+1 is the pressure of the 
! actual surface interface, not a midpoint!!

! The original routine that did this conversion allowed the bottom boundary of the lowest pressure
! level to be something other than the surface pressure and computed it with the following :
! p_surf * hybi(nlevels+1)   ! surface interface
! However, all modern SE models appear to have the lowest level boundary the same as the surface. This
! means that this can be replaced by just the surface pressure. If this is not true, careful thought is
! required, especially for the dry_mass_vertical_coordinate.
if(hybi_bottom /= 1.0_r8) then
   call error_handler(E_ERR, 'build_heights in cam_vertical_mod.f90', &
      'lowest interface hybi not exactly 1. See comments in code', source, revision, revdate)
endif 

! Put the log of the surface pressure in the top entry of the log pressure column for the conversion
pm_ln(nlevels+1) = log(p_surf)

! Some weird vertical coord could have top pressure 0, so leave this check
where (pressure >  0.0_r8)
   pm_ln(1:nlevels) = log(pressure)
else where (pressure <= 0.0_r8)
   pm_ln(1:nlevels) = 0
end where


!        height_midpts(1)=top  ->  height_midpts(nlevels)=bottom
! 
! level
! 1/2    ---------------------------------------------------------------
! 1      - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - top
! 3/2    ---------------------------------------------------------------
!
!                 ---------------------------------------------
!        --------/                                             \--------
!                - - - - - - - - - - - - - - - - - - - - - - - - 
! NL     - - - /                                                 \ - - - bottom
!              ---------------------------------------------------
! NL+1/2 -----/|||||||||||||||||||||||||||||||||||||||||||||||||||\-----


! now the finite differences.
! Eq 3.a.109 has 5 piecewise (PW) terms.  The numbers below refer to each of these terms
! in the order they're listed in the paper.

!
! See 2nd PW term here: Eq 3.a.109  where l=K,k<K  h(k,l) = 1/2 * ln [  p(k+1) / p(k) ]
!

do k = 1,nlevels - 1
   height_midpts(k) = h_surf + r_g0_tv(k) * 0.5_r8 * (pm_ln(k+1)-pm_ln(k))
enddo
height_midpts(nlevels) = h_surf + r_g0_tv(nlevels) * (pm_ln(nlevels+1)-pm_ln(nlevels))

!
! See 4th PW term here: Eq 3.a.109  where l=K,k<K  h(k,l) = 1/2*ln[pi*pi/(p(k-1)*p(k))
!

do k = 1,nlevels - 1
    height_midpts(k) = height_midpts(k) + r_g0_tv(nlevels) * &
                       (pm_ln(nlevels+1) - 0.5_r8*(pm_ln(nlevels-1)+pm_ln(nlevels)))
enddo

!
! See 3rd PW term here:  Eqs 1.14 & 3.a.109 where l>K, k<K
!                                h(k,l) = 1/2 * ln [ p(l+1)/p(l-1) ]

! don't recompute the same values multiple times;
! compute once and put into a temporary array.
! (see the double nested loops below with k and l)

! this is really a matrix multiply with a upper triangular
! matrix so it simplifies to a doubly nested loop.

! pterm(1) and (nlevels) are never used, but to prevent
! confusion when debugging set them to 0 so they don't
! look like uninitialized variables.
pterm(1)       = 0.0_r8
do k = 2,nlevels - 1
   pterm(k) = r_g0_tv(k) * 0.5_r8 * (pm_ln(k+1)-pm_ln(k-1))
enddo
pterm(nlevels) = 0.0_r8

do k = 1,nlevels - 2
   do l = k+1, nlevels-1
      height_midpts(k) = height_midpts(k) + pterm(l)
   enddo
enddo

! not implemented yet.
if (present(height_interf)) then
   height_interf(:) = MISSING_R8
endif

end subroutine build_heights

!-----------------------------------------------------------------------
!>  Convert a 2d array of geopotential altitudes to mean sea level altitudes.
!>  To avoid overflow with very high model tops, convert to km first, compute,
!>  then convert back.

subroutine gph2gmh(h, lat)
real(r8), intent(inout) :: h(:,:)    ! geopotential altitude in m
real(r8), intent(in)    :: lat       ! latitude in degrees.

real(r8), parameter ::  be = 6356.7516_r8        ! min earth radius, km
real(r8), parameter ::  ae = 6378.1363_r8        ! max earth radius, km
real(r8), parameter ::  G = 0.00980665_r8        ! WMO reference g value, km/s**2, at 45.542N(S)

real(r8) :: g0
real(r8) :: r0
real(r8) :: latr

integer :: i, j

latr = lat * DEG2RAD  ! convert to radians
call compute_surface_gravity(latr, g0)

! compute local earth's radius using ellipse equation

r0 = sqrt( ae**2 * cos(latr)**2 + be**2 * sin(latr)**2)

! Compute altitude above sea level
do j=1, size(h, 2)
   do i=1, size(h, 1)
      h(i,j) = h(i,j) / 1000.0_r8   ! m to km
      if ( ((g0*r0)/G) - h(i,j) > 0) &
         h(i,j) = (r0 * h(i,j)) / (((g0*r0)/G) - h(i,j))
      h(i,j) = h(i,j) * 1000.0_r8   ! km to m
   enddo
enddo

end subroutine gph2gmh

!-----------------------------------------------------------------------
!> This subroutine computes the Earth's gravity at any latitude.
!> The model assumes the Earth is an oblate spheriod rotating at 
!> the Earth's spin rate.  The model was taken from 
!> "Geophysical Geodesy, Kurt Lambeck, 1988".
!>
!>  input:    xlat, latitude in radians
!>  output:   galt, gravity at the given lat, km/sec**2
!>
!> taken from code from author Bill Schreiner, 5/95
!>
!>

subroutine compute_surface_gravity(xlat, galt)
real(r8), intent(in)  :: xlat
real(r8), intent(out) :: galt

real(r8),parameter :: xmu = 398600.4415_r8         ! km^3/s^2
real(r8),parameter :: ae  = 6378.1363_r8           ! km
real(r8),parameter :: f   = 1.0_r8/298.2564_r8
real(r8),parameter :: xm  = 0.003468_r8            !
real(r8),parameter :: f2  = 5.3481622134089e-03_r8 ! f2 = -f + 5.0* 0.50*xm - 17.0/14.0*f*xm + 15.0/4.0*xm**2
real(r8),parameter :: f4  = 2.3448248012911e-05_r8 ! f4 = -f**2* 0.50 + 5.0* 0.50*f*xm

real(r8) :: g
!real(r8) :: alt = 0.0_r8

! gravity at the equator, km/s2
real(r8), parameter :: ge = xmu/ae**2/(1.0_r8 - f + 1.5_r8*xm - 15.0_r8/14.0_r8*xm*f)


! compute gravity at any latitude, km/s2
g = ge*(1.0_r8 + f2*(sin(xlat))**2 - 1.0_r8/4.0_r8*f4*(sin(2.0_r8*xlat))**2)

! at a fixed altitude of 0.0, g and galt are the same
galt = g

! FIXME: if alt is hardcoded to 0.0, none of this code is needed.
!
! keep it for now in case we want gravity to vary with height.
!
!! compute gravity at any latitude and at any height, km/s2
!galt = g - 2.0_r8*ge*alt/ae*(1.0_r8 + f + xm + (-3.0_r8*f + 5.0_r8* 0.50_r8*xm)*  &
!                          (sin(xlat))**2) + 3.0_r8*ge*alt**2/ae**2
!
!if (g /= galt) print *, 'g, galt: ', g, galt
!
!!! compute gravity at any latitude, km/s2
!!galt = ge*(1.0_r8 + f2*(sin(xlat))**2 - 1.0_r8/4.0_r8*f4*(sin(2.0_r8*xlat))**2)
!
!! convert to meters/s2
!!galt = galt*1000.0_r8

end subroutine compute_surface_gravity

!-----------------------------------------------------------------------
!> interpolate in the vertical between 2 arrays of items.
!>
!> vert_fracts: 0 is 100% of the first level and 
!>              1 is 100% of the second level

subroutine vert_interp(nitems, levs1, levs2, vert_fracts, out_vals)
integer,  intent(in)  :: nitems
real(r8), intent(in)  :: levs1(nitems)
real(r8), intent(in)  :: levs2(nitems)
real(r8), intent(in)  :: vert_fracts(nitems)
real(r8), intent(out) :: out_vals(nitems)

out_vals(:) = (levs1(:) * (1.0_r8-vert_fracts(:))) + &
              (levs2(:) *         vert_fracts(:))

end subroutine vert_interp

!--------------------------------------------------------------------
!> in cam level 1 is at the model top, level N is the lowest level
!> our convention in this code is:  between levels a fraction of 0
!> is 100% level 1, and fraction of 1 is 100% level 2.

function check_good_levels(vert_value, valid_range, l1, l2, fract)
real(r8), intent(in)  :: vert_value
integer,  intent(in)  :: valid_range
integer,  intent(out) :: l1
integer,  intent(out) :: l2
real(r8), intent(out) :: fract
logical               :: check_good_levels

integer :: integer_level
real(r8) :: fract_level

! be a pessimist, then you're never disappointed
check_good_levels = .false.
l1 = MISSING_I
l2 = MISSING_I
fract = MISSING_R8

! out of range checks
if (vert_value < 1.0_r8 .or. vert_value > valid_range) return

integer_level = floor(vert_value)
fract_level = vert_value - integer_level

! cam levels start at the top so level 1 is
! the highest level and increases on the way down.

!>might want to allow extrapolation - which means
!>allowing out of range values here and handling
!>them correctly in the calling and vert_interp() code.

if (vert_value /= valid_range) then
   l1 = integer_level
   l2 = integer_level + 1
   fract = fract_level
else
   ! equal to the largest level number
   l1 = integer_level - 1
   l2 = integer_level
   fract = 1.0_r8
endif

check_good_levels = .true.

end function check_good_levels

!-----------------------------------------------------------------------
!> return the level indices and fraction across the level.
!> level 1 is model top, level N is model bottom. 
!> height is largest at the top, so the values *are* inverted
!> in the array.
!> fract = 0 means full lev1 value,
!> fract = 1 means full lev2 value. 
!> return non-zero if value outside valid range.

subroutine height_to_level(nlevels, heights, h_val, &
                            lev1, lev2, fract, my_status)

integer,  intent(in)  :: nlevels
real(r8), intent(in)  :: heights(:)
real(r8), intent(in)  :: h_val
integer,  intent(out) :: lev1
integer,  intent(out) :: lev2
real(r8), intent(out) :: fract
integer,  intent(out) :: my_status

character(len=*), parameter :: routine = 'height_to_level:'

my_status = 0

call find_enclosing_indices(nlevels, heights, h_val, lev1, lev2, fract, my_status, &
                            inverted = .true., log_scale = .false.)

if (my_status /= 0) my_status = 11

end subroutine height_to_level

!-----------------------------------------------------------------------
!> return the level indices and fraction across the level.
!> level 1 is model top, level N is model bottom. 
!> pressure is smallest at the top, so the values are not inverted
!> in the array.
!> fract = 0 means full lev1 value,
!> fract = 1 means full lev2 value. 
!> return non-zero if value outside valid range.

subroutine pressure_to_level(nlevels, pressures, p_val, log_scale, &
                              lev1, lev2, fract, my_status)

integer,  intent(in)  :: nlevels
real(r8), intent(in)  :: pressures(:)
real(r8), intent(in)  :: p_val
logical,  intent(in)  :: log_scale   ! interpolate in log(pressure)
integer,  intent(out) :: lev1
integer,  intent(out) :: lev2
real(r8), intent(out) :: fract
integer,  intent(out) :: my_status

my_status = 0

call find_enclosing_indices(nlevels, pressures, p_val, lev1, lev2, fract, my_status, &
                            inverted = .false., log_scale = log_scale)

if (my_status /= 0) my_status = 10

end subroutine pressure_to_level

!-----------------------------------------------------------------------
!> Compute the pressures at the layer midpoints for multiple columns

subroutine build_cam_pressure_columns(ens_size, surface_pressure, n_levels, &
                                      ref_surface_pressure, hyam, hybm, pressure_array)

integer,            intent(in)  :: ens_size
real(r8),           intent(in)  :: surface_pressure(:)   ! in pascals
integer,            intent(in)  :: n_levels
real(r8),           intent(in)  :: ref_surface_pressure  ! P0, in pascals
real(r8),           intent(in)  :: hyam(:), hybm(:)      ! hybrid coefficients at layer midpoints
real(r8),           intent(out) :: pressure_array(:,:)

integer :: j

! Set midpoint pressures.  This array mirrors the order of the
! cam model levels: 1 is the model top, N is the bottom.

do j=1, ens_size
   call single_pressure_column(surface_pressure(j), n_levels, ref_surface_pressure, &
                               hyam, hybm, pressure_array(:, j))
enddo

end subroutine build_cam_pressure_columns

!-----------------------------------------------------------------------
!> Compute column of pressures at the layer midpoints for the given
!> surface pressure.
!>
!> to get pressure on layer interfaces, the computation would be identical
!> but use hyai, hybi.  (also have n_levels+1)

subroutine single_pressure_column(surface_pressure, n_levels, ref_surface_pressure, &
                                  hyam, hybm, pressure_array)

real(r8),           intent(in)  :: surface_pressure   ! in pascals
integer,            intent(in)  :: n_levels
real(r8),           intent(in)  :: ref_surface_pressure  ! P0, in pascals
real(r8),           intent(in)  :: hyam(:), hybm(:)
real(r8),           intent(out) :: pressure_array(n_levels)

!SENote: There is an inconsistency between hyam and the mean of surrounding hyai in the
! caminput.nc files. Suspect that a few of the hyam's are bad, but it could also be
! they hyai's or some combination. For now, need to compare
! to results for the dry mass which use the hyai, so switch to that here.
! Have switched back to try to maintain bitwise consistency with original versions
! but this issue needs to be resolved with the CAM developers.
! (the alternative using the mean of hyai(k) and hyai(k+1) in place of hyam(k)
!  was tried and abandoned.)

pressure_array(1:n_levels) = ref_surface_pressure * hyam(1:n_levels) + &
                                surface_pressure * hybm(1:n_levels)

end subroutine single_pressure_column

!--------------------------------------------------------------------
! Function to calculate scale height given a pressure and optionally
! a surface pressure.  (See the namelist item which controls whether to
! normalize the pressure value aloft with the surface pressure or not.
! We currently only use scale height for computing distances between
! two locations, so the surface pressure terms cancel out - exactly if
! the two locations are co-located horizontally, almost if they are not.
! Normalizing by the surface pressure means in areas of high orography
! the surface differences propagate all the way to the model top.  
! To be backwards-compatible, do this normalization; the current thinking 
! is we shouldn't do it both for scientific reasons and because it 
! doubles the work if it's expensive to find the correct horizontal 
! location, i.e. mpas irregular grids. In this model we always have
! the surface pressure at a location so it's not a performance issue.)
!
! Watch out for unusual cases that could crash the log() function
! We pass in the surface pressure here even if it isn't going to be
! used because in all the cases above we seem to have it (or the standard
! reference pressure) everywhere we are going to compute this value.
! The "skip_norm" parameter controls whether this code uses the 
! surface pressure or not. 

function scale_height(p_above, p_surface, skip_norm)
real(r8), intent(in) :: p_above
real(r8), intent(in) :: p_surface
logical,  intent(in) :: skip_norm
real(r8)             :: scale_height

real(r8), parameter :: tiny = epsilon(1.0_r8)
real(r8) :: diff

if (skip_norm) then
   scale_height = log(p_above)
   return
endif

diff = p_surface - p_above  ! should be positive

if (abs(diff) < tiny) then
   ! surface obs will have (almost) identical values
   scale_height = 0.0_r8   ! -log(1.0_r8)

else if (diff <= tiny .or. p_above <= 0.0_r8) then
   ! weed out bad cases
   scale_height = MISSING_R8

else
   ! normal computation - should be safe now
   scale_height = -log(p_above / p_surface )

endif

end function scale_height

!-----------------------------------------------------------------------
!> Fill a table of pressures and heights based on a std atmosphere.
!>  not precise - use only when rough numbers are good enough.
!>  returns which table was used.  If the table is already loaded
!>  it is not loaded a second time.
!>
!> table from: http://www.pdas.com/atmos.html
!> and also see:  http://www.pdas.com/upatmos.html
!> for a good explanation of why you can't use the standard
!> equations at high altitudes.   the low tables came from
!> tables.c, and the high one came from bigtables.out.
!> (all found in the atmos.zip file from that web site.)

function init_std_atm_table(table, this_model_top)
type(std_atm_table_type), intent(inout) :: table
real(r8),                 intent(in)    :: this_model_top
integer :: init_std_atm_table

if (this_model_top < high_top_threshold) then
   if (.not. allocated(table%hgt)) call load_high_top_table(table)
   init_std_atm_table = HIGH_TOP_TABLE
else
   if (.not. allocated(table%hgt)) call load_low_top_table(table)
   init_std_atm_table = LOW_TOP_TABLE
endif

table%table_kind = init_std_atm_table

end function init_std_atm_table

!-----------------------------------------------------------------------
!> Free arrays associated with the table

subroutine free_std_atm_table(table)
type(std_atm_table_type), intent(inout) :: table

if (allocated(table%hgt))  deallocate(table%hgt)
if (allocated(table%pres)) deallocate(table%pres)
table%len = 0
table%table_kind = -1

end subroutine free_std_atm_table

!--------------------------------------------------------------------
!> using a standard atmosphere pressure column, convert a pressure directly to height

function std_atm_pressure_to_height(table, pressure, log_scale, status)
type(std_atm_table_type), intent(in)  :: table
real(r8),                 intent(in)  :: pressure
logical,                  intent(in)  :: log_scale
integer,                  intent(out) :: status
real(r8) :: std_atm_pressure_to_height

integer :: lev1, lev2
real(r8) :: fract

std_atm_pressure_to_height = MISSING_R8

call pressure_to_level(table%len, table%pres, pressure, log_scale, &
                       lev1, lev2, fract, status)
if (status /= 0) return

std_atm_pressure_to_height = table%hgt(lev1) * (1.0_r8 - fract) + &
                             table%hgt(lev2) * (fract)

end function std_atm_pressure_to_height

!--------------------------------------------------------------------
!> using a standard atmosphere pressure column, convert a height directly to pressure

function std_atm_height_to_pressure(table, height, status)
type(std_atm_table_type), intent(in)  :: table
real(r8),                 intent(in)  :: height
integer,                  intent(out) :: status
real(r8) :: std_atm_height_to_pressure

integer :: lev1, lev2
real(r8) :: fract

std_atm_height_to_pressure = MISSING_R8

call height_to_level(table%len, table%hgt, height, &
                     lev1, lev2, fract, status)
if (status /= 0) return

std_atm_height_to_pressure = table%pres(lev1) * (1.0_r8-fract) + &
                             table%pres(lev2) * (fract)

end function std_atm_height_to_pressure

!--------------------------------------------------------------------

subroutine load_low_top_table(table)
type(std_atm_table_type), intent(inout) :: table

        
table%len = 45
allocate(table%hgt(table%len), table%pres(table%len))
        
table%hgt(1)  = 86.0_r8 ; table%pres(1)  = 3.732E-01_r8
table%hgt(2)  = 84.0_r8 ; table%pres(2)  = 5.308E-01_r8
table%hgt(3)  = 82.0_r8 ; table%pres(3)  = 7.498E-01_r8
table%hgt(4)  = 80.0_r8 ; table%pres(4)  = 1.052E+00_r8
table%hgt(5)  = 78.0_r8 ; table%pres(5)  = 1.467E+00_r8
table%hgt(6)  = 76.0_r8 ; table%pres(6)  = 2.033E+00_r8
table%hgt(7)  = 74.0_r8 ; table%pres(7)  = 2.800E+00_r8
table%hgt(8)  = 72.0_r8 ; table%pres(8)  = 3.835E+00_r8
table%hgt(9)  = 70.0_r8 ; table%pres(9)  = 5.220E+00_r8
table%hgt(10) = 68.0_r8 ; table%pres(10) = 7.051E+00_r8
table%hgt(11) = 66.0_r8 ; table%pres(11) = 9.459E+00_r8
table%hgt(12) = 64.0_r8 ; table%pres(12) = 1.260E+01_r8
table%hgt(13) = 62.0_r8 ; table%pres(13) = 1.669E+01_r8
table%hgt(14) = 60.0_r8 ; table%pres(14) = 2.196E+01_r8
table%hgt(15) = 58.0_r8 ; table%pres(15) = 2.872E+01_r8
table%hgt(16) = 56.0_r8 ; table%pres(16) = 3.736E+01_r8
table%hgt(17) = 54.0_r8 ; table%pres(17) = 4.833E+01_r8
table%hgt(18) = 52.0_r8 ; table%pres(18) = 6.221E+01_r8
table%hgt(19) = 50.0_r8 ; table%pres(19) = 7.977E+01_r8
table%hgt(20) = 48.0_r8 ; table%pres(20) = 1.023E+02_r8
table%hgt(21) = 46.0_r8 ; table%pres(21) = 1.313E+02_r8
table%hgt(22) = 44.0_r8 ; table%pres(22) = 1.695E+02_r8
table%hgt(23) = 42.0_r8 ; table%pres(23) = 2.200E+02_r8
table%hgt(24) = 40.0_r8 ; table%pres(24) = 2.871E+02_r8
table%hgt(25) = 38.0_r8 ; table%pres(25) = 3.771E+02_r8
table%hgt(26) = 36.0_r8 ; table%pres(26) = 4.985E+02_r8
table%hgt(27) = 34.0_r8 ; table%pres(27) = 6.634E+02_r8
table%hgt(28) = 32.0_r8 ; table%pres(28) = 8.890E+02_r8
table%hgt(29) = 30.0_r8 ; table%pres(29) = 1.197E+03_r8
table%hgt(30) = 28.0_r8 ; table%pres(30) = 1.616E+03_r8
table%hgt(31) = 26.0_r8 ; table%pres(31) = 2.188E+03_r8
table%hgt(32) = 24.0_r8 ; table%pres(32) = 2.972E+03_r8
table%hgt(33) = 22.0_r8 ; table%pres(33) = 4.047E+03_r8
table%hgt(34) = 20.0_r8 ; table%pres(34) = 5.529E+03_r8
table%hgt(35) = 18.0_r8 ; table%pres(35) = 7.565E+03_r8
table%hgt(36) = 16.0_r8 ; table%pres(36) = 1.035E+04_r8
table%hgt(37) = 14.0_r8 ; table%pres(37) = 1.417E+04_r8
table%hgt(38) = 12.0_r8 ; table%pres(38) = 1.940E+04_r8
table%hgt(39) = 10.0_r8 ; table%pres(39) = 2.650E+04_r8
table%hgt(40) =  8.0_r8 ; table%pres(40) = 3.565E+04_r8
table%hgt(41) =  6.0_r8 ; table%pres(41) = 4.722E+04_r8
table%hgt(42) =  4.0_r8 ; table%pres(42) = 6.166E+04_r8
table%hgt(43) =  2.0_r8 ; table%pres(43) = 7.950E+04_r8
table%hgt(44) =  0.0_r8 ; table%pres(44) = 1.013E+05_r8
table%hgt(45) = -2.0_r8 ; table%pres(45) = 1.278E+05_r8

! convert km to m
table%hgt(:) = table%hgt(:) * 1000.0_r8
        
end subroutine load_low_top_table

subroutine load_high_top_table(table)
type(std_atm_table_type), intent(inout) :: table


table%len = 201
allocate(table%hgt(table%len), table%pres(table%len))

table%hgt(1)   = 1000.0_r8  ;  table%pres(1)   = 7.518E-09_r8
table%hgt(2)   =  995.0_r8  ;  table%pres(2)   = 7.651E-09_r8
table%hgt(3)   =  990.0_r8  ;  table%pres(3)   = 7.790E-09_r8
table%hgt(4)   =  985.0_r8  ;  table%pres(4)   = 7.931E-09_r8
table%hgt(5)   =  980.0_r8  ;  table%pres(5)   = 8.075E-09_r8
table%hgt(6)   =  975.0_r8  ;  table%pres(6)   = 8.222E-09_r8
table%hgt(7)   =  970.0_r8  ;  table%pres(7)   = 8.371E-09_r8
table%hgt(8)   =  965.0_r8  ;  table%pres(8)   = 8.524E-09_r8
table%hgt(9)   =  960.0_r8  ;  table%pres(9)   = 8.680E-09_r8
table%hgt(10)  =  955.0_r8  ;  table%pres(10)  = 8.839E-09_r8
table%hgt(11)  =  950.0_r8  ;  table%pres(11)  = 9.001E-09_r8
table%hgt(12)  =  945.0_r8  ;  table%pres(12)  = 9.168E-09_r8
table%hgt(13)  =  940.0_r8  ;  table%pres(13)  = 9.338E-09_r8
table%hgt(14)  =  935.0_r8  ;  table%pres(14)  = 9.513E-09_r8
table%hgt(15)  =  930.0_r8  ;  table%pres(15)  = 9.692E-09_r8
table%hgt(16)  =  925.0_r8  ;  table%pres(16)  = 9.875E-09_r8
table%hgt(17)  =  920.0_r8  ;  table%pres(17)  = 1.006E-08_r8
table%hgt(18)  =  915.0_r8  ;  table%pres(18)  = 1.026E-08_r8
table%hgt(19)  =  910.0_r8  ;  table%pres(19)  = 1.046E-08_r8
table%hgt(20)  =  905.0_r8  ;  table%pres(20)  = 1.066E-08_r8
table%hgt(21)  =  900.0_r8  ;  table%pres(21)  = 1.087E-08_r8
table%hgt(22)  =  895.0_r8  ;  table%pres(22)  = 1.109E-08_r8
table%hgt(23)  =  890.0_r8  ;  table%pres(23)  = 1.132E-08_r8
table%hgt(24)  =  885.0_r8  ;  table%pres(24)  = 1.155E-08_r8
table%hgt(25)  =  880.0_r8  ;  table%pres(25)  = 1.179E-08_r8
table%hgt(26)  =  875.0_r8  ;  table%pres(26)  = 1.203E-08_r8
table%hgt(27)  =  870.0_r8  ;  table%pres(27)  = 1.229E-08_r8
table%hgt(28)  =  865.0_r8  ;  table%pres(28)  = 1.255E-08_r8
table%hgt(29)  =  860.0_r8  ;  table%pres(29)  = 1.283E-08_r8
table%hgt(30)  =  855.0_r8  ;  table%pres(30)  = 1.311E-08_r8
table%hgt(31)  =  850.0_r8  ;  table%pres(31)  = 1.340E-08_r8
table%hgt(32)  =  845.0_r8  ;  table%pres(32)  = 1.371E-08_r8
table%hgt(33)  =  840.0_r8  ;  table%pres(33)  = 1.402E-08_r8
table%hgt(34)  =  835.0_r8  ;  table%pres(34)  = 1.435E-08_r8
table%hgt(35)  =  830.0_r8  ;  table%pres(35)  = 1.469E-08_r8
table%hgt(36)  =  825.0_r8  ;  table%pres(36)  = 1.504E-08_r8
table%hgt(37)  =  820.0_r8  ;  table%pres(37)  = 1.541E-08_r8
table%hgt(38)  =  815.0_r8  ;  table%pres(38)  = 1.579E-08_r8
table%hgt(39)  =  810.0_r8  ;  table%pres(39)  = 1.619E-08_r8
table%hgt(40)  =  805.0_r8  ;  table%pres(40)  = 1.660E-08_r8
table%hgt(41)  =  800.0_r8  ;  table%pres(41)  = 1.704E-08_r8
table%hgt(42)  =  795.0_r8  ;  table%pres(42)  = 1.749E-08_r8
table%hgt(43)  =  790.0_r8  ;  table%pres(43)  = 1.795E-08_r8
table%hgt(44)  =  785.0_r8  ;  table%pres(44)  = 1.844E-08_r8
table%hgt(45)  =  780.0_r8  ;  table%pres(45)  = 1.896E-08_r8
table%hgt(46)  =  775.0_r8  ;  table%pres(46)  = 1.949E-08_r8
table%hgt(47)  =  770.0_r8  ;  table%pres(47)  = 2.006E-08_r8
table%hgt(48)  =  765.0_r8  ;  table%pres(48)  = 2.064E-08_r8
table%hgt(49)  =  760.0_r8  ;  table%pres(49)  = 2.126E-08_r8
table%hgt(50)  =  755.0_r8  ;  table%pres(50)  = 2.191E-08_r8
table%hgt(51)  =  750.0_r8  ;  table%pres(51)  = 2.260E-08_r8
table%hgt(52)  =  745.0_r8  ;  table%pres(52)  = 2.331E-08_r8
table%hgt(53)  =  740.0_r8  ;  table%pres(53)  = 2.407E-08_r8
table%hgt(54)  =  735.0_r8  ;  table%pres(54)  = 2.487E-08_r8
table%hgt(55)  =  730.0_r8  ;  table%pres(55)  = 2.571E-08_r8
table%hgt(56)  =  725.0_r8  ;  table%pres(56)  = 2.660E-08_r8
table%hgt(57)  =  720.0_r8  ;  table%pres(57)  = 2.755E-08_r8
table%hgt(58)  =  715.0_r8  ;  table%pres(58)  = 2.854E-08_r8
table%hgt(59)  =  710.0_r8  ;  table%pres(59)  = 2.960E-08_r8
table%hgt(60)  =  705.0_r8  ;  table%pres(60)  = 3.072E-08_r8
table%hgt(61)  =  700.0_r8  ;  table%pres(61)  = 3.191E-08_r8
table%hgt(62)  =  695.0_r8  ;  table%pres(62)  = 3.317E-08_r8
table%hgt(63)  =  690.0_r8  ;  table%pres(63)  = 3.451E-08_r8
table%hgt(64)  =  685.0_r8  ;  table%pres(64)  = 3.594E-08_r8
table%hgt(65)  =  680.0_r8  ;  table%pres(65)  = 3.746E-08_r8
table%hgt(66)  =  675.0_r8  ;  table%pres(66)  = 3.908E-08_r8
table%hgt(67)  =  670.0_r8  ;  table%pres(67)  = 4.080E-08_r8
table%hgt(68)  =  665.0_r8  ;  table%pres(68)  = 4.264E-08_r8
table%hgt(69)  =  660.0_r8  ;  table%pres(69)  = 4.459E-08_r8
table%hgt(70)  =  655.0_r8  ;  table%pres(70)  = 4.668E-08_r8
table%hgt(71)  =  650.0_r8  ;  table%pres(71)  = 4.892E-08_r8
table%hgt(72)  =  645.0_r8  ;  table%pres(72)  = 5.130E-08_r8
table%hgt(73)  =  640.0_r8  ;  table%pres(73)  = 5.385E-08_r8
table%hgt(74)  =  635.0_r8  ;  table%pres(74)  = 5.659E-08_r8
table%hgt(75)  =  630.0_r8  ;  table%pres(75)  = 5.951E-08_r8
table%hgt(76)  =  625.0_r8  ;  table%pres(76)  = 6.264E-08_r8
table%hgt(77)  =  620.0_r8  ;  table%pres(77)  = 6.600E-08_r8
table%hgt(78)  =  615.0_r8  ;  table%pres(78)  = 6.961E-08_r8
table%hgt(79)  =  610.0_r8  ;  table%pres(79)  = 7.349E-08_r8
table%hgt(80)  =  605.0_r8  ;  table%pres(80)  = 7.765E-08_r8
table%hgt(81)  =  600.0_r8  ;  table%pres(81)  = 8.213E-08_r8
table%hgt(82)  =  595.0_r8  ;  table%pres(82)  = 8.695E-08_r8
table%hgt(83)  =  590.0_r8  ;  table%pres(83)  = 9.214E-08_r8
table%hgt(84)  =  585.0_r8  ;  table%pres(84)  = 9.774E-08_r8
table%hgt(85)  =  580.0_r8  ;  table%pres(85)  = 1.038E-07_r8
table%hgt(86)  =  575.0_r8  ;  table%pres(86)  = 1.103E-07_r8
table%hgt(87)  =  570.0_r8  ;  table%pres(87)  = 1.173E-07_r8
table%hgt(88)  =  565.0_r8  ;  table%pres(88)  = 1.249E-07_r8
table%hgt(89)  =  560.0_r8  ;  table%pres(89)  = 1.330E-07_r8
table%hgt(90)  =  555.0_r8  ;  table%pres(90)  = 1.418E-07_r8
table%hgt(91)  =  550.0_r8  ;  table%pres(91)  = 1.514E-07_r8
table%hgt(92)  =  545.0_r8  ;  table%pres(92)  = 1.617E-07_r8
table%hgt(93)  =  540.0_r8  ;  table%pres(93)  = 1.728E-07_r8
table%hgt(94)  =  535.0_r8  ;  table%pres(94)  = 1.849E-07_r8
table%hgt(95)  =  530.0_r8  ;  table%pres(95)  = 1.979E-07_r8
table%hgt(96)  =  525.0_r8  ;  table%pres(96)  = 2.120E-07_r8
table%hgt(97)  =  520.0_r8  ;  table%pres(97)  = 2.273E-07_r8
table%hgt(98)  =  515.0_r8  ;  table%pres(98)  = 2.439E-07_r8
table%hgt(99)  =  510.0_r8  ;  table%pres(99)  = 2.618E-07_r8
table%hgt(100) =  505.0_r8  ;  table%pres(100) = 2.813E-07_r8
table%hgt(101) =  500.0_r8  ;  table%pres(101) = 3.024E-07_r8
table%hgt(102) =  495.0_r8  ;  table%pres(102) = 3.252E-07_r8
table%hgt(103) =  490.0_r8  ;  table%pres(103) = 3.501E-07_r8
table%hgt(104) =  485.0_r8  ;  table%pres(104) = 3.770E-07_r8
table%hgt(105) =  480.0_r8  ;  table%pres(105) = 4.063E-07_r8
table%hgt(106) =  475.0_r8  ;  table%pres(106) = 4.382E-07_r8
table%hgt(107) =  470.0_r8  ;  table%pres(107) = 4.728E-07_r8
table%hgt(108) =  465.0_r8  ;  table%pres(108) = 5.104E-07_r8
table%hgt(109) =  460.0_r8  ;  table%pres(109) = 5.514E-07_r8
table%hgt(110) =  455.0_r8  ;  table%pres(110) = 5.960E-07_r8
table%hgt(111) =  450.0_r8  ;  table%pres(111) = 6.445E-07_r8
table%hgt(112) =  445.0_r8  ;  table%pres(112) = 6.974E-07_r8
table%hgt(113) =  440.0_r8  ;  table%pres(113) = 7.550E-07_r8
table%hgt(114) =  435.0_r8  ;  table%pres(114) = 8.179E-07_r8
table%hgt(115) =  430.0_r8  ;  table%pres(115) = 8.864E-07_r8
table%hgt(116) =  425.0_r8  ;  table%pres(116) = 9.612E-07_r8
table%hgt(117) =  420.0_r8  ;  table%pres(117) = 1.043E-06_r8
table%hgt(118) =  415.0_r8  ;  table%pres(118) = 1.132E-06_r8
table%hgt(119) =  410.0_r8  ;  table%pres(119) = 1.229E-06_r8
table%hgt(120) =  405.0_r8  ;  table%pres(120) = 1.336E-06_r8
table%hgt(121) =  400.0_r8  ;  table%pres(121) = 1.452E-06_r8
table%hgt(122) =  395.0_r8  ;  table%pres(122) = 1.579E-06_r8
table%hgt(123) =  390.0_r8  ;  table%pres(123) = 1.718E-06_r8
table%hgt(124) =  385.0_r8  ;  table%pres(124) = 1.870E-06_r8
table%hgt(125) =  380.0_r8  ;  table%pres(125) = 2.037E-06_r8
table%hgt(126) =  375.0_r8  ;  table%pres(126) = 2.220E-06_r8
table%hgt(127) =  370.0_r8  ;  table%pres(127) = 2.421E-06_r8
table%hgt(128) =  365.0_r8  ;  table%pres(128) = 2.641E-06_r8
table%hgt(129) =  360.0_r8  ;  table%pres(129) = 2.884E-06_r8
table%hgt(130) =  355.0_r8  ;  table%pres(130) = 3.151E-06_r8
table%hgt(131) =  350.0_r8  ;  table%pres(131) = 3.445E-06_r8
table%hgt(132) =  345.0_r8  ;  table%pres(132) = 3.769E-06_r8
table%hgt(133) =  340.0_r8  ;  table%pres(133) = 4.126E-06_r8
table%hgt(134) =  335.0_r8  ;  table%pres(134) = 4.521E-06_r8
table%hgt(135) =  330.0_r8  ;  table%pres(135) = 4.957E-06_r8
table%hgt(136) =  325.0_r8  ;  table%pres(136) = 5.440E-06_r8
table%hgt(137) =  320.0_r8  ;  table%pres(137) = 5.975E-06_r8
table%hgt(138) =  315.0_r8  ;  table%pres(138) = 6.568E-06_r8
table%hgt(139) =  310.0_r8  ;  table%pres(139) = 7.226E-06_r8
table%hgt(140) =  305.0_r8  ;  table%pres(140) = 7.957E-06_r8
table%hgt(141) =  300.0_r8  ;  table%pres(141) = 8.770E-06_r8
table%hgt(142) =  295.0_r8  ;  table%pres(142) = 9.676E-06_r8
table%hgt(143) =  290.0_r8  ;  table%pres(143) = 1.069E-05_r8
table%hgt(144) =  285.0_r8  ;  table%pres(144) = 1.181E-05_r8
table%hgt(145) =  280.0_r8  ;  table%pres(145) = 1.308E-05_r8
table%hgt(146) =  275.0_r8  ;  table%pres(146) = 1.449E-05_r8
table%hgt(147) =  270.0_r8  ;  table%pres(147) = 1.608E-05_r8
table%hgt(148) =  265.0_r8  ;  table%pres(148) = 1.787E-05_r8
table%hgt(149) =  260.0_r8  ;  table%pres(149) = 1.989E-05_r8
table%hgt(150) =  255.0_r8  ;  table%pres(150) = 2.218E-05_r8
table%hgt(151) =  250.0_r8  ;  table%pres(151) = 2.476E-05_r8
table%hgt(152) =  245.0_r8  ;  table%pres(152) = 2.770E-05_r8
table%hgt(153) =  240.0_r8  ;  table%pres(153) = 3.105E-05_r8
table%hgt(154) =  235.0_r8  ;  table%pres(154) = 3.488E-05_r8
table%hgt(155) =  230.0_r8  ;  table%pres(155) = 3.927E-05_r8
table%hgt(156) =  225.0_r8  ;  table%pres(156) = 4.432E-05_r8
table%hgt(157) =  220.0_r8  ;  table%pres(157) = 5.015E-05_r8
table%hgt(158) =  215.0_r8  ;  table%pres(158) = 5.690E-05_r8
table%hgt(159) =  210.0_r8  ;  table%pres(159) = 6.476E-05_r8
table%hgt(160) =  205.0_r8  ;  table%pres(160) = 7.394E-05_r8
table%hgt(161) =  200.0_r8  ;  table%pres(161) = 8.474E-05_r8
table%hgt(162) =  195.0_r8  ;  table%pres(162) = 9.749E-05_r8
table%hgt(163) =  190.0_r8  ;  table%pres(163) = 1.127E-04_r8
table%hgt(164) =  185.0_r8  ;  table%pres(164) = 1.308E-04_r8
table%hgt(165) =  180.0_r8  ;  table%pres(165) = 1.527E-04_r8
table%hgt(166) =  175.0_r8  ;  table%pres(166) = 1.794E-04_r8
table%hgt(167) =  170.0_r8  ;  table%pres(167) = 2.121E-04_r8
table%hgt(168) =  165.0_r8  ;  table%pres(168) = 2.528E-04_r8
table%hgt(169) =  160.0_r8  ;  table%pres(169) = 3.039E-04_r8
table%hgt(170) =  155.0_r8  ;  table%pres(170) = 3.693E-04_r8
table%hgt(171) =  150.0_r8  ;  table%pres(171) = 4.542E-04_r8
table%hgt(172) =  145.0_r8  ;  table%pres(172) = 5.669E-04_r8
table%hgt(173) =  140.0_r8  ;  table%pres(173) = 7.203E-04_r8
table%hgt(174) =  135.0_r8  ;  table%pres(174) = 9.357E-04_r8
table%hgt(175) =  130.0_r8  ;  table%pres(175) = 1.250E-03_r8
table%hgt(176) =  125.0_r8  ;  table%pres(176) = 1.736E-03_r8
table%hgt(177) =  120.0_r8  ;  table%pres(177) = 2.537E-03_r8
table%hgt(178) =  115.0_r8  ;  table%pres(178) = 4.004E-03_r8
table%hgt(179) =  110.0_r8  ;  table%pres(179) = 7.149E-03_r8
table%hgt(180) =  105.0_r8  ;  table%pres(180) = 1.442E-02_r8
table%hgt(181) =  100.0_r8  ;  table%pres(181) = 3.201E-02_r8
table%hgt(182) =   95.0_r8  ;  table%pres(182) = 7.577E-02_r8
table%hgt(183) =   90.0_r8  ;  table%pres(183) = 1.844E-01_r8
table%hgt(184) =   85.0_r8  ;  table%pres(184) = 4.457E-01_r8
table%hgt(185) =   80.0_r8  ;  table%pres(185) = 1.052E+00_r8
table%hgt(186) =   75.0_r8  ;  table%pres(186) = 2.388E+00_r8
table%hgt(187) =   70.0_r8  ;  table%pres(187) = 5.221E+00_r8
table%hgt(188) =   65.0_r8  ;  table%pres(188) = 1.093E+01_r8
table%hgt(189) =   60.0_r8  ;  table%pres(189) = 2.196E+01_r8
table%hgt(190) =   55.0_r8  ;  table%pres(190) = 4.253E+01_r8
table%hgt(191) =   50.0_r8  ;  table%pres(191) = 7.978E+01_r8
table%hgt(192) =   45.0_r8  ;  table%pres(192) = 1.491E+02_r8
table%hgt(193) =   40.0_r8  ;  table%pres(193) = 2.871E+02_r8
table%hgt(194) =   35.0_r8  ;  table%pres(194) = 5.746E+02_r8
table%hgt(195) =   30.0_r8  ;  table%pres(195) = 1.197E+03_r8
table%hgt(196) =   25.0_r8  ;  table%pres(196) = 2.549E+03_r8
table%hgt(197) =   20.0_r8  ;  table%pres(197) = 5.529E+03_r8
table%hgt(198) =   15.0_r8  ;  table%pres(198) = 1.211E+04_r8
table%hgt(199) =   10.0_r8  ;  table%pres(199) = 2.650E+04_r8
table%hgt(200) =    5.0_r8  ;  table%pres(200) = 5.405E+04_r8
table%hgt(201) =    0.0_r8  ;  table%pres(201) = 1.013E+05_r8

! convert km to m
table%hgt(:) = table%hgt(:) * 1000.0_r8

end subroutine load_high_top_table

end module cam_vertical_mod
