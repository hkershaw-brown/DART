#!/usr/bin/env bash

# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

main() {

export DART=$(git rev-parse --show-toplevel)
source "$DART"/build_templates/buildfunctions.sh

MODEL="none"
EXTRA="$DART"/models/template/threed_model_mod.f90
LOCATION="threed_sphere"
dev_test=1
TEST="mpi_utilities"

# mpi_utils_basic_test, mpi_utils_pt2pt_test and the trigger_* /
# mpi_utils_null_errors_test programs need no namelist options that
# aren't already reachable, so they build the normal way.  The
# make_copy_before_broadcast / make_copy_before_sendrecv regression
# coverage in mpi_utils_collectives_test needs the mpi_utilities_nml
# namelist to actually be read, which the shipped mpi_utilities_mod.f90/
# mpif08_utilities_mod.f90 do not do by default (read_namelist is
# hardcoded .false.).  Rather than changing the shipped module, build
# mpi_utils_collectives_test against a local, build-time-patched copy of
# whichever backend was selected -- see build_patched_target() below.

programs=(
mpi_utils_basic_test
mpi_utils_pt2pt_test
)

# mpi_utils_null_errors_test and its trigger_* programs are only
# meaningful against null_mpi_utilities_mod.f90 (they check that
# send_to/receive_from/get_from_fwd/get_from_mean abort, which is
# specific to the null backend -- under mpi/mpif08 these routines do
# real communication instead). serial_programs always builds against
# null_mpi_utilities_mod.f90 regardless of the mpi/nompi/mpif08 CLI
# arg, which is also what keeps the trigger_get_from_fwd/
# trigger_get_from_mean window arguments plain integers instead of
# mpif08's type(MPI_Win).
serial_programs=(
mpi_utils_null_errors_test
trigger_send_to
trigger_receive_from
trigger_get_from_fwd
trigger_get_from_mean
)

# quickbuild arguments
arguments "$@"

# buildit() forces mpisrc="null_mpi" and clears the mkmf wrapper flag
# once it gets to the (here, empty) serial_programs array, and leaves
# them that way -- save the real selection now so build_patched_target
# can restore it after buildit() runs.
orig_mpisrc="$mpisrc"
orig_m="$m"

# clean the directory
\rm -f -- *.o *.mod Makefile .cppdefs patched_*.f90

# build and run preprocess before making any other DART executables
buildpreprocess

#-------------------------
# Build mpi_utils_collectives_test against a build-time-patched copy of
# the selected mpi backend source, with read_namelist forced to .true.
# so mpi_utilities_nml (make_copy_before_broadcast in particular) is
# actually read from input.nml for this one binary.  The patch is
# derived from the real source at build time -- nothing here is hand
# maintained, and every other target in this file still builds against
# the real, unmodified module.
#-------------------------
build_patched_target() {

mpisrc="$orig_mpisrc"
m="$orig_m"

if [ "$mpisrc" == "mpi" ]; then
   real="$DART"/assimilation_code/modules/utilities/mpi_utilities_mod.f90
elif [ "$mpisrc" == "mpif08" ]; then
   real="$DART"/assimilation_code/modules/utilities/mpif08_utilities_mod.f90
else
   # null_mpi_utilities_mod.f90 has no namelist to patch -- build normally
   real=""
fi

findsrc

if [ -n "$real" ]; then
   patched="$(pwd)/patched_$(basename "$real")"
   sed 's/read_namelist = \.false\./read_namelist = .true./' "$real" > "$patched"
   dartsrc=${dartsrc//$real/$patched}
fi

echo "Building  mpi_utils_collectives_test"
dartbuild mpi_utils_collectives_test

}

# build the plain-namelist programs
# (buildit exits internally once single_prog is set and matched, so the
# collectives-test case must be intercepted before calling buildit at all)
if [ "$single_prog" == "mpi_utils_collectives_test" ]; then
   build_patched_target
elif [ -z "$single_prog" ]; then
   buildit
   build_patched_target
else
   buildit
fi

# clean up
\rm -f -- *.o *.mod patched_*.f90

}

main "$@"
