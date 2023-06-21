program test_ran_unif

use random_seq_mod, only : ran_unif, init_ran, random_seq_type
use types_mod, only : r8
implicit none

integer :: seed, i
type(random_seq_type) :: r
real(r8) :: real_random_number

seed = 13

call init_ran(r, seed)

do i = 1, 11
  real_random_number = ran_unif(r)
enddo

end program test_ran_unif
