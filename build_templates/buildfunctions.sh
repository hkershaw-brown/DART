#!/bin/bash

#-------------------------
# Collect the source files needed to build DART
# Arguments:
#  location module (e.g. threed_sphere, oned)
# Globals:
#  dartsrc - created buy this function
#-------------------------
function findsrc() {

local core=$(find $DART/src/core -type f -name "*.f90") 
local modelsrc=$(find ../src -type d -name programs -prune -o -type f -name "*.f90" -print)
local loc="$DART/src/location/$1 \
                $DART/src/model_mod_tools/test_interpolate_$1.f90"

local misc="$DART/src/location/utilities \
            $DART/src/null_mpi \
            $DART/models/utilities/default_model_mod.f90 \
            $DART/observations/forward_operators/obs_def_mod.f90 \
            $DART/observations/forward_operators/obs_def_utilities_mod.f90"

dartsrc="${core} ${modelsrc} ${misc} ${loc}"
}

#-------------------------
# Build a program 
# Arguements: 
#  program name
# Globals:
#  DART - root of DART
#  dartsrc - source files
#-------------------------
function buildit() {
 $DART/build_templates/mkmf -x -p $1 \
     $DART/src/programs/$1 \
     $dartsrc
}

#-------------------------
# Build a model specific program
# looks in ../src for {main}.f90 
# Arguements: 
#  program name
# Globals:
#  DART - root of DART
#  dartsrc - source files
#-------------------------
function build() {
 $DART/build_templates/mkmf -p $1 ../src/programs/$1.f90 \
     $dartsrc
 make $1
}

#-------------------------
# Build and run preprocess
# Arguements: 
#  none
# Globals:
#  DART - root of DART
#-------------------------
function buildpreprocess() {
 $DART/build_templates/mkmf -p preprocess -a $DART $DART/src/programs/preprocess/path_names_preprocess
 make
 ./preprocess
}
