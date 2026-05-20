program test_location_missing

use location_mod, only : set_location, location_type, &
                         set_location_missing, query_location, &
                         get_dist, get_close_init, get_close_obs, &
                         get_close_type
use types_mod, only : r8
use utilities_mod, only : initialize_utilities, finalize_utilities

implicit none

type(location_type) :: state_loc, mis_loc, locs(2), obs_loc
integer :: locs_qtys(2)
real(r8) :: dist
integer :: num_close, close_ind(2)
type(get_close_type) :: gc

call initialize_utilities() 

state_loc =  set_location(0.3_r8)
obs_loc = state_loc
mis_loc = set_location_missing()

print*, 'loc 1', query_location(state_loc, 'x')
print*, 'loc 2', query_location(mis_loc, 'x')
print*, 'obs loc', query_location(obs_loc, 'x')

locs(1) = state_loc
locs(2) = mis_loc
locs_qtys(:) = 1

call get_close_init(gc, 2, 0.4_r8, locs)

dist = get_dist(state_loc, mis_loc)
print*, 'dist ', dist

call get_close_obs(gc, obs_loc, locs_qtys(1), locs, locs_qtys, locs_qtys, num_close, close_ind)

print*, 'num_close', num_close
print*, 'close_ind', close_ind

call finalize_utilities()

end program test_location_missing
