module cam_qty_mod

! Small helpers that classify DART quantities for the CAM model_mods.
! No module-level state: the state structure domain id is passed in.

use obs_kind_mod,        only : QTY_SURFACE_ELEVATION, QTY_SURFACE_PRESSURE, QTY_PRESSURE, &
                                QTY_VERTLEVEL, QTY_GEOMETRIC_HEIGHT
use state_structure_mod, only : get_varid_from_kind

implicit none
private

public :: is_surface_field, ok_to_interpolate

contains

!-----------------------------------------------------------------------
!> return 0 (ok) if we know how to interpolate this quantity.
!> if it is a field in the state, return the variable id from
!> the state structure.  if not in the state, varid will return -1

subroutine ok_to_interpolate(domain_id, obs_qty, varid, my_status)
integer, intent(in)  :: domain_id   ! state structure domain
integer, intent(in)  :: obs_qty
integer, intent(out) :: varid
integer, intent(out) :: my_status

! See if the state contains the obs quantity 
varid = get_varid_from_kind(domain_id, obs_qty)

! in the state vector
if (varid > 0) then
   my_status = 0
   return
endif

! add any quantities that can be interpolated to this list if they
! are not in the state vector.
select case (obs_qty)
   case (QTY_SURFACE_ELEVATION, &
         QTY_PRESSURE,          &
         QTY_GEOMETRIC_HEIGHT,  &
         QTY_VERTLEVEL)
      my_status = 0
   case default
      my_status = 2
end select

end subroutine ok_to_interpolate

!--------------------------------------------------------------------

! add any 2d fields here that are surface quantities

function is_surface_field(qty)
integer, intent(in) :: qty
logical :: is_surface_field

select case (qty)
 case (QTY_SURFACE_PRESSURE, QTY_SURFACE_ELEVATION)
   is_surface_field = .true.

! example:
! case (QTY_SFNUM_A1, QTY_SFNUM_A2, QTY_SFNUM_A3, QTY_SFNUM_A4, QTY_SFPOM_A4, QTY_SFBC_A4, &
!       QTY_SFSO4_A1, QTY_SFSO4_A2, QTY_SFCO,     QTY_SFCO01,   QTY_SFCO02 ) 
!   is_surface_field = .true.

 case default
   is_surface_field = .false.

end select

end function is_surface_field

end module cam_qty_mod
