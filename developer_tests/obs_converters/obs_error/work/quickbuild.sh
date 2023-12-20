#!/usr/bin/env bash

# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

main() {


export DART=$(git rev-parse --show-toplevel)
source "$DART"/build_templates/buildfunctions.sh

MODEL="none"
EXTRA="$DART/models/template/threed_model_mod.f90 \
       $DART/developer_tests/obs_converters/obs_error/obs_ncep_error_test.f90 \
       $DART/observations/obs_converters/obs_error/ncep_obs_err_mod.f90"
LOCATION="threed_sphere"
dev_test=1
TEST="obs_ncep_error_test"

serial_programs=(
obs_ncep_error_test
)


# quickbuild arguments
arguments "$@"

# clean the directory
\rm -f -- *.o *.mod Makefile .cppdefs

# build and run preprocess before making any other DART executables
buildpreprocess

# build 
buildit

# clean up
\rm -f -- *.o *.mod

}

main "$@"
