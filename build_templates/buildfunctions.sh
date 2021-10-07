#!/bin/bash


#-------------------------
# Collect the source files needed to build DART
# Arguments:
#  location module (e.g. threed_sphere, oned)
# Globals:
#  dartsrc - created buy this function
#  location - stores the location module
#  DART - expected in the enviroment
#-------------------------
function findsrc() {

local core=$(find $DART/src/core -type f -name "*.f90") 
local modelsrc=$(find $DART/models/$MODEL/src -type d -name programs -prune -o -type f -name "*.f90" -print)
local loc="$DART/src/location/$1 \
           $DART/src/model_mod_tools/test_interpolate_$1.f90"
local misc="$DART/src/location/utilities \
            $DART/src/null_mpi \
            $DART/models/utilities/default_model_mod.f90 \
            $DART/observations/forward_operators/obs_def_mod.f90 \
            $DART/observations/forward_operators/obs_def_utilities_mod.f90"

location=$1

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

#look in $program directory for {main}.f90 
local program

if [ $1 == "obs_diag" ]; then
 echo "Doing obs_diag" 
 program=$DART/src/programs/obs_diag/$location
else
 program=$DART/src/programs/$1
fi

 $DART/build_templates/mkmf -x -p $1 \
     $dartsrc \
     $program
}

#-------------------------
# Build a model specific program
# looks in $DART/models/$MODEL/src/programs for {main}.f90 
# Arguements: 
#  program name
# Globals:
#  DART - root of DART
#  dartsrc - source files
#-------------------------
function build() {
 $DART/build_templates/mkmf -x -p $1 $DART/models/$MODEL/src/programs/$1.f90 \
     $dartsrc
}

#-------------------------
# Build and run preprocess
# Arguements: 
#  none
# Globals:
#  DART - root of DART
#-------------------------
function buildpreprocess() {

 # run preprocess if it is in the current directory
 if [ -f preprocess ]; then
   echo "already there"
   ./preprocess
   return

 # link to preprocess if it is already built
 if [ -f $DART/src/programs/preprocess/preprocess ]; then
    echo "not there but built"
    ln -s $DART/src/programs/preprocess/preprocess .
    ./preprocess 
    return
 fi

 # build preproces
 $DART/build_templates/mkmf -x -p $DART/src/programs/preprocess/preprocess -a $DART $DART/src/programs/preprocess/path_names_preprocess
 ln -s $DART/src/programs/preprocess/preprocess .
 ./preprocess
}
