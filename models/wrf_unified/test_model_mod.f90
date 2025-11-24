submodule (model_mod) test_model_mod

contains

subroutine test_get_wrf_domain()

! Test the get_wrf_domain function with example data

integer, allocatable :: test_wrf_dom(:)
integer :: test_num_domains, test_num_state_domains
integer :: i, result

! Example setup: 3 domains, 6 state IDs
test_num_domains = 3
test_num_state_domains = 6
allocate(test_wrf_dom(test_num_state_domains))
test_wrf_dom = [101, 102, 103, 201, 202, 203]

! Assign to module variables
num_domains = test_num_domains
if (allocated(wrf_dom)) deallocate(wrf_dom)
allocate(wrf_dom(test_num_state_domains))
wrf_dom = test_wrf_dom

print *, 'Testing get_wrf_domain:'
do i = 1, test_num_state_domains
    result = get_wrf_domain(test_wrf_dom(i))
    print *, 'state_id=', test_wrf_dom(i), ' -> domain=', result
end do

! Test for a state_id not in wrf_dom
result = get_wrf_domain(999)
print *, 'state_id=999 -> domain=', result, ' (should indicate not found)'

! Clean up
if (allocated(wrf_dom)) deallocate(wrf_dom)
if (allocated(test_wrf_dom)) deallocate(test_wrf_dom)


end subroutine test_get_wrf_domain

end submodule test_model_mod
