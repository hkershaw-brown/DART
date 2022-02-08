#!/bin/tcsh

mkdir Saver

cp \
 assimilation_code/modules/utilities/null_mpi_utilities_mod.f90   \
 diagnostics/matlab/gen_rean_diags.m                \
 models/cam-fv/shell_scripts/cesm2_1/DART_config.template     \
 models/cam-fv/shell_scripts/cesm2_1/setup_advanced \
 models/cam-fv/shell_scripts/cesm2_1/setup_hybrid   \
 models/cam-fv/shell_scripts/cesm2_1_Zagar/setup_advanced     \
 models/cam-fv/shell_scripts/cesm2_1_Zagar/setup_pmo   \
 models/cam-fv/work/input.nml                       \
 models/cam-fv/work/minimal_build.csh               \
 models/cam-fv/work/quickbuild.csh                  \
 models/template/work/input.nml                     \
 Saver
