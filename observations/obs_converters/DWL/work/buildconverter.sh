#!/bin/bash

main() {
set -e

[ -z "$DART" ] && echo "ERROR: Must set DART environment variable" && exit 9

CONVERTER=DWL
LOCATION=threed_sphere
source $DART/build_templates/buildconvfunctions.sh

programs=( \
obs_sequence_tool \
path_names_advance_time
)

# don't need arguments
# quickbuild arguments
#arguments "$@"

# clean the directory
\rm -f *.o *.mod Makefile .cppdefs

# build and run preprocess before making any other DART executables
buildpreprocess

# build 
buildconv


# clean up
\rm -f *.o *.mod

}

main "$@"
