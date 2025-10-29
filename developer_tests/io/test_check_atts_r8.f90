! test_io_filenames_mod.f90
program test_check_attribute_value_r8
   use io_filenames_mod, only : check_attribute_value_r8
   use utilities_mod, only : initialize_utilities, finalize_utilities
   use types_mod, only: r8
   use netcdf
   use, intrinsic :: ieee_arithmetic
   implicit none

   integer :: ncid, varid, retval
   character(len=256) :: filename
   character(len=32)  :: varname, attname
   real(r8) :: att_value, test_value
   real(r8) :: nan_value
   integer :: dimid

   call initialize_utilities()

   test_value = 42.0_r8
   nan_value = ieee_value(0.0_r8, ieee_quiet_nan)
   varname = 'testvar'
   attname = 'missing_value'


   ! Open file for reading
   retval = nf90_open('test_42.nc', NF90_NOWRITE, ncid)
   retval = nf90_inq_varid(ncid, varname, varid)

   print *, 'Test 1: Matching value (should not error)'
   call check_attribute_value_r8(ncid, 'test_42_r8.nc', varid, attname, test_value)

   print *, 'Test 2: Non-matching value (should error)'
   call check_attribute_value_r8(ncid, 'test_42_r8.nc', varid, attname, test_value + 1.0_r8)
   retval = nf90_close(ncid)

   print *, 'Test 3: Attribute is NaN, input is not NaN (should error)', nan_value, test_value
   ! Open file for reading
   retval = nf90_open('test_nan_r8.nc', NF90_NOWRITE, ncid)
   retval = nf90_inq_varid(ncid, varname, varid)

   call check_attribute_value_r8(ncid, 'test_nan_r8.nc', varid, attname, test_value)

   print *, 'Test 4: Attribute is NaN, input is NaN (should not error)'
   call check_attribute_value_r8(ncid, 'test_nan_r8.nc', varid, attname, nan_value)

   retval = nf90_close(ncid)
   call finalize_utilities()

end program test_check_attribute_value_r8

