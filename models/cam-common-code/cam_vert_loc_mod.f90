module cam_vert_loc_mod

! Everything about how CAM does vertical localization: which vertical
! coordinate to localize in, discarding obs above a user-set level, and
! damping the increments near the model top.
!
! All the settings live in a cam_vert_config object which the model_mod owns
! and passes to each routine.  There is no module-level state and the
! namelist is never seen here: the model_mod copies the values it needs into
! the config.  The pure math lives in cam_vertical_mod.

use types_mod,       only : MISSING_R8, r8
use utilities_mod,   only : E_ERR, E_MSG, error_handler, to_upper
use location_mod,    only : location_type, get_close_type, get_dist, set_location, get_maxdist, &
                            VERTISUNDEF, VERTISPRESSURE, VERTISHEIGHT, VERTISLEVEL, &
                            VERTISSCALEHEIGHT, VERTISSURFACE, set_vertical_localization_coord
use cam_grid_mod,    only : cam_grid
use cam_vertical_mod, only : single_pressure_column, scale_height, std_atm_table_type, &
                             init_std_atm_table, free_std_atm_table, std_atm_pressure_to_height, &
                             HIGH_TOP_TABLE

implicit none
private

public :: cam_vert_config, set_vert_localization, init_sign_of_vert_units, &
          init_discard_high_obs, init_damping_ramp_info, obs_too_high, &
          above_ramp_start, free_vert_config

! version controlled file description for error handling, do not edit
character(len=*), parameter :: source   = 'cam_vert_loc_mod.f90'
character(len=*), parameter :: revision = ''
character(len=*), parameter :: revdate  = ''

!> The vertical localization settings.  Set the two namelist-derived
!> items directly, then call the init_* routines to fill in the rest.
type cam_vert_config
   ! from the model_mod namelist
   logical  :: use_log_vertical_scale             = .false.
   logical  :: no_normalization_of_scale_heights  = .true.

   ! default to localizing in pressure.  set by set_vert_localization
   integer  :: localization_type = VERTISPRESSURE

   ! flag used to know if the vertical unit system has numbers
   ! that get larger as you move away from the earth's surface
   ! (e.g. height) or smaller (e.g. pressure).  set by init_sign_of_vert_units
   logical  :: higher_is_smaller = .true.

   ! things related to damping at the model top
   logical  :: are_damping = .false.
   real(r8) :: ramp_end    = MISSING_R8   ! fixed top of ramp; the start (bottom) varies

   ! discarding obs above a user-defined level
   logical  :: discarding_high_obs      = .false.
   real(r8) :: no_assim_above_height    = -1.0_r8
   real(r8) :: no_assim_above_level     = -1.0_r8
   real(r8) :: no_assim_above_pressure  = -1.0_r8

   ! pressure <-> height map to convert the above.
   type(std_atm_table_type) :: std_atm
end type

contains

!-----------------------------------------------------------------------
!> free the space held in the config

subroutine free_vert_config(cfg)
type(cam_vert_config), intent(inout) :: cfg

call free_std_atm_table(cfg%std_atm)

end subroutine free_vert_config

!-----------------------------------------------------------------------
!> return my_status /= 0 if obs is above a user-defined threshold.
!> intended to be quick (low-cost) and not exact. 
!> This intentionally does NOT have a case for vert type of
!> SCALEHEIGHT - because this routine is only used to look at
!> observation locations.  we have not yet encountered obs
!> with that vertical type.

subroutine obs_too_high(cfg, vert_value, which_vert, my_status)
type(cam_vert_config), intent(in) :: cfg
real(r8), intent(in) :: vert_value
integer,  intent(in) :: which_vert
integer, intent(out) :: my_status

character(len=512) :: string2

! assume ok to begin with
my_status = 0

if (which_vert == VERTISPRESSURE) then
   ! lower pressures are higher; watch the less than/greater than tests
   if (vert_value < cfg%no_assim_above_pressure) my_status = 14
   return
endif

! these are always ok
if (which_vert == VERTISSURFACE .or. which_vert == VERTISUNDEF) return

if (which_vert == VERTISHEIGHT) then
   if (vert_value > cfg%no_assim_above_height) my_status = 14
   return
endif

if (which_vert == VERTISLEVEL) then
   ! level 1 is top; watch less than/greater than in tests
   if (vert_value < cfg%no_assim_above_level) my_status = 14
   return
endif

! for now we haven't run into observations where the vertical coordinate
! (of the OBS) is in scale height - but if we do it will fall into here.

write(string2, *) 'vertical type: ', which_vert
call error_handler(E_ERR, 'obs_too_high', 'unrecognized vertical type', &
                   source, revision, revdate, text2=string2)

end subroutine obs_too_high

!-----------------------------------------------------------------------
!> convert from string to integer, and set in the dart code the
!> vertical type we are going to want to localize in.

subroutine set_vert_localization(cfg, typename)
type(cam_vert_config), intent(inout) :: cfg
character(len=*),      intent(in)    :: typename

character(len=*), parameter :: routine = 'set_vert_localization'

character(len=32) :: ucasename
integer :: vcoord
character(len=512) :: string1, string2

ucasename = typename
call to_upper(ucasename)

select case (ucasename)
  case ("PRESSURE")
     vcoord = VERTISPRESSURE
  case ("HEIGHT")
     vcoord = VERTISHEIGHT
  case ("SCALEHEIGHT", "SCALE_HEIGHT", "SCALE HEIGHT")
     vcoord = VERTISSCALEHEIGHT
  case ("LEVEL", "MODEL_LEVEL", "MODEL LEVEL")
     vcoord = VERTISLEVEL
  case default
     write(string1,*)'unrecognized vertical localization coordinate type: '//trim(typename)
     write(string2,*)'valid values are: PRESSURE, HEIGHT, SCALEHEIGHT, LEVEL'
     call error_handler(E_ERR,routine,string1,source,revision,revdate,text2=string2)
end select

! during assimilation, when get_close() is called to compute the separation distance
! between items, convert all state and obs to use this vertical type if vertical localization 
! is enabled (usually true for cam).

call set_vertical_localization_coord(vcoord)

! save in the config for later use.
cfg%localization_type = vcoord

end subroutine set_vert_localization

!--------------------------------------------------------------------

subroutine init_discard_high_obs(cfg, grid, no_obs_assim_above_level)

type(cam_vert_config), intent(inout) :: cfg
type(cam_grid),        intent(in)    :: grid
integer,               intent(in)    :: no_obs_assim_above_level

! compute a conversion table between height and pressure based on
! a surface pressure of 1010 mb.  this is a fixed table and does not
! vary with temperature, humidity or surface elevation. 
! use only for quick conversions when absolute accuracy 
! isn't a primary concern. It also is based on the standard (not the dry
! mass) vertical coordinate. If there were a situation where the differences
! were big might want to find a way to do this with dry mass, but probably
! not an issue for any earth atmosphere.

character(len=*), parameter :: routine = 'init_discard_high_obs'
integer :: my_status

integer :: table_type
character(len=16) :: out_fmt, out_fmt1, pres_fmt
character(len=512) :: string1, string2, string3
real(r8) :: no_assim_above_scaleh
real(r8) :: temp_p_col(grid%ref_nlevels)

! pick the better table: 
!  one is more accurate for the lower atmosphere, 
!  and the other has a very high top.
table_type = init_std_atm_table(cfg%std_atm, grid%ref_model_top_pressure)

! set formatting which is easiest to read in the log.
! the very high top table has very small numbers that need
! exponential notation.
out_fmt  = '(A,F12.5,A)'
out_fmt1 = '(A,I5)'
pres_fmt = out_fmt
if (table_type == HIGH_TOP_TABLE) pres_fmt = '(A,E12.5,A)'

! levels can be fractional but the namelist only allows integer, so simplify the formatting
write(string1, out_fmt1) &
   'Discarding observations higher than model level ', no_obs_assim_above_level
call error_handler(E_MSG, 'init_discard_high_obs', string1, source, revision, revdate)

! SENote: Accuracy in this computation is not necessary. This just assumed a dry climatological 
! column and is one of only two places that the dry vertical coordinate interface ignores
! the impact of water tracers.
call single_pressure_column(grid%ref_surface_pressure, grid%ref_nlevels, &
                            grid%ref_surface_pressure, grid%hyam%vals, grid%hybm%vals, temp_p_col)
cfg%no_assim_above_pressure = temp_p_col(no_obs_assim_above_level)
write(string1, pres_fmt) &
   ' ... which is equivalent to pressure level ', cfg%no_assim_above_pressure, ' Pascals'
call error_handler(E_MSG, 'init_discard_high_obs', string1, source, revision, revdate)

cfg%no_assim_above_height = std_atm_pressure_to_height(cfg%std_atm, cfg%no_assim_above_pressure, &
                                                       cfg%use_log_vertical_scale, my_status)
if (my_status /= 0) then
   call error_handler(E_ERR, routine, 'error converting pressure to height', &
                      source, revision, revdate, text2='"no_assim_above_pressure" invalid value')
endif

write(string1, out_fmt) &
   ' ... which is equivalent to height         ', cfg%no_assim_above_height, ' meters'
call error_handler(E_MSG, 'init_discard_high_obs', string1, source, revision, revdate)

! print this out, but don't save the value unless we encounter
! incoming observations which have vertical units of scale height.
! so far we have localized in scale height but never had obs
! which had an incoming vertical unit of scale height.
no_assim_above_scaleh = scale_height(cfg%no_assim_above_pressure, grid%ref_surface_pressure, .false.)
write(string1, out_fmt) &
   ' ... which is equivalent to scale height   ', no_assim_above_scaleh
call error_handler(E_MSG, 'init_discard_high_obs', string1, source, revision, revdate)

! only now that everything worked is it safe to start discarding
cfg%discarding_high_obs = .true.

end subroutine init_discard_high_obs

!--------------------------------------------------------------------
! initialize what we can here.  the highest end of the ramp is fixed;
! the start depends on the cutoff distance which can be observation
! type dependent.  at the time the ramping adjustment is applied all
! vertical coordinates will have already been converted to the
! vertical localization type.

subroutine init_damping_ramp_info(cfg, grid, model_damping_ends_at_level)

type(cam_vert_config), intent(inout) :: cfg
type(cam_grid),        intent(in)    :: grid
integer,               intent(in)    :: model_damping_ends_at_level

real(r8) :: model_top

character(len=*), parameter :: routine = 'init_damping_ramp_info'

integer :: table_type
character(len=16) :: out_fmt
character(len=512) :: string1, string2, string3

! pick the better table: 
!  one is more accurate for the lower atmosphere, 
!  and the other has a very high top.
table_type = init_std_atm_table(cfg%std_atm, grid%ref_model_top_pressure)

! set formatting which is easiest to read in the log.
! the very high top table has very small numbers that need
! exponential notation.
out_fmt = '(A,F12.5,A)'
if (table_type == HIGH_TOP_TABLE .and. &
    cfg%localization_type == VERTISPRESSURE) out_fmt = '(A,E12.5,A)'

! convert to vertical localization units
call convert_vertical_level_generic(cfg, grid, model_damping_ends_at_level, &
                                    cfg%localization_type, cfg%ramp_end, string3, no_norm=.false.)

! check for conversion errors
if (cfg%ramp_end == MISSING_R8) then
   write(string1, *) 'error converting ramp_end to vertical localization units'
   call error_handler(E_MSG, routine, 'unexpected error', &
                      source, revision, revdate, text2=string1)
endif

! this value only used for print statement, unused otherwise
call convert_vertical_level_generic(cfg, grid, 1, cfg%localization_type, &
                                    model_top, string3, no_norm=.false.)

! check for conversion errors
if (model_top == MISSING_R8) then
   write(string1, *) 'error converting model_top to vertical localization units'
   call error_handler(E_MSG, routine, 'unexpected error', &
                      source, revision, revdate, text2=string1)
endif

! at this point, ramp_end and model_top are in the localization units

! let the log know what we're doing
write(string1, '(A,I5)') 'Increments will go to 0.0 at model level ', model_damping_ends_at_level
write(string2, out_fmt) 'which is ', cfg%ramp_end, ' '//trim(string3)
call error_handler(E_MSG, routine, &
   'Decreasing increments in region damped in the model', &
   string1, source, revision, revdate, text2=string1, text3=string2)

write(string1, out_fmt) 'For reference, model top is ', model_top, ' '//trim(string3)
call error_handler(E_MSG, routine, string1, source, revision, revdate)

cfg%are_damping = .true.

end subroutine init_damping_ramp_info

!--------------------------------------------------------------------
!> for pressure, level, and one flavor of scale height
!> smaller numbers are further away from the surface.
!> for height and the other flavor of scale height 
!> the opposite is true.  set this once at init time.

subroutine init_sign_of_vert_units(cfg)
type(cam_vert_config), intent(inout) :: cfg

if (cfg%localization_type == VERTISHEIGHT) then
   cfg%higher_is_smaller = .false.

else if (cfg%localization_type == VERTISSCALEHEIGHT) then
   ! FIXME: note from nick on scale height:
   !  If no_normalization_of_scale_heights is true, then SH=log(pressure), 
   !  and scale height will decrease with increasing height. 
   !  However, if it is false then SH= -1*log(pressure/surface_pressure) 
   !  and it will increase with increasing height. 

   if (cfg%no_normalization_of_scale_heights) then
      cfg%higher_is_smaller = .true.
   else
      cfg%higher_is_smaller = .false.
   endif

else
   cfg%higher_is_smaller = .true.

endif

end subroutine init_sign_of_vert_units

!--------------------------------------------------------------------
!> this should only be used for converting vertical values which
!> are the same for all ensemble members at all locations. 
!> it uses generic values to do a vertical conversion.

subroutine convert_vertical_level_generic(cfg, grid, level_value, want_vert_type, out_value, out_label, no_norm)
type(cam_vert_config), intent(in)       :: cfg
type(cam_grid),   intent(in)            :: grid
integer,          intent(in)            :: level_value
integer,          intent(in)            :: want_vert_type
real(r8),         intent(out)           :: out_value
character(len=*), intent(out), optional :: out_label
logical,          intent(in),  optional :: no_norm

character(len=*), parameter :: routine = 'convert_vertical_level_generic'

integer  :: status
real(r8) :: tmp_val, temp_p_col(grid%ref_nlevels)
logical  :: no_norm_flag
character(len=512) :: string1, string2, string3

if (present(no_norm)) then
   no_norm_flag = no_norm
else
   no_norm_flag = cfg%no_normalization_of_scale_heights
endif

if (want_vert_type == VERTISLEVEL) then
    out_value = real(level_value, r8)
    if (present(out_label)) out_label = 'levels'
else
   ! convert to the requested units.  start by going to pressure
   ! SENote: Accuracy in this computation is not necessary. This just assumed a dry climatological 
   ! column and is one of only two places that the dry vertical coordinate interface ignores
   ! the impact of water tracers.
   call single_pressure_column(grid%ref_surface_pressure, grid%ref_nlevels, &
                               grid%ref_surface_pressure, grid%hyam%vals, grid%hybm%vals, temp_p_col)
   tmp_val = temp_p_col(level_value)

   select case (want_vert_type)
     case (VERTISPRESSURE)
       out_value = tmp_val
       if (present(out_label)) out_label = 'pascals'

     case (VERTISSCALEHEIGHT)
       out_value = scale_height(tmp_val, grid%ref_surface_pressure, no_norm_flag)
       if (present(out_label)) out_label = 'scale heights'

     case (VERTISHEIGHT)
       out_value = std_atm_pressure_to_height(cfg%std_atm, tmp_val, &
                                              cfg%use_log_vertical_scale, status)
       if (status /= 0) out_value = MISSING_R8
       if (present(out_label)) out_label = 'meters'

     case default
       write(string1, *) 'unknown requested vertical type ', want_vert_type
       call error_handler(E_MSG, routine, 'unexpected error', &
                          source, revision, revdate, text2=string1)
   end select
endif

end subroutine convert_vertical_level_generic

!--------------------------------------------------------------------
! JLA Make sure that sections are coherenet at the end
! vertical functions - these deal with the fact that pressure,
! scale height, and model levels all get larger as you go from 
! higher in the atmosphere to lower in the atmosphere, but height 
! is the opposite.  these all depend on the global setting of the
! vertical localization type.


!--------------------------------------------------------------------
!> pressure gets smaller as you go up, everything else gets larger.
!> return true if this value is above the start of the ramp.
!> test_value and ramp_end need to already be in vert localization units

! FIXME: test this new code section carefully.
!
! right now the calling code is expecting extra_dist to be added
! to the original get_dist() value, so any scaling or modifications
! should happen in this routine.
!
! do we need the 2 locations here to compute the horizontal distance?
! or is having the total dist and the vertical separation enough?

function above_ramp_start(cfg, test_value, gc, obs_type, total_dist, extra_dist)
type(cam_vert_config), intent(in) :: cfg
real(r8),             intent(in)  :: test_value
type(get_close_type), intent(in)  :: gc
integer,              intent(in)  :: obs_type
real(r8),             intent(in)  :: total_dist
real(r8),             intent(out) :: extra_dist
logical :: above_ramp_start

real(r8) :: ramp_end, vert_localize_dist, ramp_start, norm, vert_norm, vert_only_dist
real(r8) :: horiz_dist, ramp_dist, ramp_width
type(location_type) :: this_loc, ramp_start_loc, loc1, loc2
logical, save :: onetime = .true.

ramp_end = cfg%ramp_end


! do the easy cases first - either above the ramp end
! or below the ramp start.  leave the middle ground for
! last because we have to then compute a damping factor.

! FIXME: test this!!!
! is it above the ramp end? set damp dist to something
! large enough to turn off all impacts.  is vert_localize_dist enough?
vert_localize_dist = get_maxdist(gc, obs_type)
if (.false. .and. onetime) then
   print *, 'vert_localize_dist = ', vert_localize_dist
   onetime = .false.
endif

if (v_above(cfg%higher_is_smaller, test_value, ramp_end)) then
   extra_dist = vert_localize_dist
   above_ramp_start = .true.
   return
endif

! compute ramp start and see if we're lower than that.

! vert norm for this obs type
loc1 = set_location(0.0_r8, 0.0_r8, 0.0_r8, cfg%localization_type)
loc2 = set_location(0.0_r8, 0.0_r8, 1.0_r8, cfg%localization_type)
norm = get_dist(loc1, loc2, obs_type)   ! units: rad/loc units
vert_norm = 1.0_r8 / norm               ! units now: loc units/rad

ramp_start = v_down(cfg%higher_is_smaller, ramp_end, vert_norm * vert_localize_dist)

!print *, 'computing ramp start: ramp_end, vert_norm, vert_localize_dist', &
!                    ramp_start, ramp_end, vert_norm, vert_localize_dist

if (.not. v_above(cfg%higher_is_smaller, test_value, ramp_start)) then
   extra_dist = 0.0_r8
   above_ramp_start = .false.
   return
endif



! ok, we're somewhere inbetween.  compute horiz and vert distances
! and see what the ramping factor needs to be.

!print *, 'test value within ramp range: ', ramp_start, test_value, ramp_end
above_ramp_start = .true.

! see what the vertical separation is from obs to start of ramp
this_loc       = set_location(0.0_r8, 0.0_r8, test_value, cfg%localization_type)
ramp_start_loc = set_location(0.0_r8, 0.0_r8, ramp_start, cfg%localization_type)

! do we need this?  i think so.   radians
vert_only_dist = get_dist(ramp_start_loc, this_loc, obs_type)

! we need this to compute what?
if (vert_only_dist > total_dist) then
   !print *, 'unexpected, vert larger than total:  ', vert_only_dist, total_dist
   !print *, 'obs_type, vert_norm = ', obs_type, vert_norm
   horiz_dist = 0.0_r8
else
   horiz_dist = sqrt(total_dist**2 - vert_only_dist**2)
endif

ramp_dist  = v_difference(test_value, ramp_start)
ramp_width = v_difference(ramp_end,   ramp_start)
extra_dist = (ramp_dist / ramp_width) * vert_localize_dist

! DEBUG - disable for now
if (.false. .and. above_ramp_start) then
   print *, 'ramp s/v/e: ', ramp_start, test_value, ramp_end
   print *, 'v, h:       ', vert_only_dist, horiz_dist
   print *, 'rampd, tot: ', ramp_dist, ramp_width
   print *, 'ed, return: ', extra_dist, above_ramp_start
endif

end function above_ramp_start

!--------------------------------------------------------------------
! returns true if a is above b (higher in the atmosphere, 
! further from the surface of the earth).  

pure function v_above(higher_is_smaller, a, b)
logical,  intent(in) :: higher_is_smaller
real(r8), intent(in) :: a, b
logical :: v_above

if (higher_is_smaller) then
   v_above = (a < b)
else
   v_above = (a > b)
endif

end function v_above

!--------------------------------------------------------------------
! returns new value of moving b distance down in the atmosphere
! starting at a.  for height, this results in a smaller value
! (also one flavor of scale height), but for other vertical types 
! this results in a larger value.

pure function v_down(higher_is_smaller, a, b)
logical,  intent(in) :: higher_is_smaller
real(r8), intent(in) :: a, b
real(r8) :: v_down

if (higher_is_smaller) then
   v_down = (a + b)
else
   v_down = (a - b)
endif

end function v_down

!--------------------------------------------------------------------
! returns difference of a and b
! (doesn't depend on the cfg%localization_type)

pure function v_difference(a, b)
real(r8), intent(in) :: a, b
real(r8) :: v_difference

v_difference = abs(a - b)

end function v_difference

end module cam_vert_loc_mod
