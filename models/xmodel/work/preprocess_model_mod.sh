#!/usr/bin/env bash

# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

#-------------------------
# Preprocess model_mod.f90 to add model-specific prefixes
# This allows multiple model_mods to be compiled into one executable
#-------------------------

set -e

if [ $# -lt 3 ]; then
  echo "Usage: $0 <model_name> <model_mod_path> <output_path>"
  echo "  model_name: short name for the model (e.g., camfv, wrf)"
  echo "  model_mod_path: path to the original model_mod.f90"
  echo "  output_path: path for the renamed model_mod.f90"
  exit 1
fi

MODEL_NAME=$1
MODEL_MOD_PATH=$2
OUTPUT_PATH=$3

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_PATH")"

echo "Preprocessing $MODEL_MOD_PATH for model: $MODEL_NAME"
echo "Output will be written to: $OUTPUT_PATH"

# List of standard model_mod routines that need to be renamed
# These are the required public interfaces
ROUTINES=(
  "static_init_model"
  "get_model_size"
  "get_state_meta_data"
  "shortest_time_between_assimilations"
  "model_interpolate"
  "nc_write_model_atts"
  "nc_write_model_vars"
  "write_model_time"
  "read_model_time"
  "end_model"
  "pert_model_copies"
  "get_close_obs"
  "get_close_state"
  "convert_vertical_obs"
  "convert_vertical_state"
  "adv_1step"
  "init_time"
  "init_conditions"
)

# Start with the original file
cp "$MODEL_MOD_PATH" "$OUTPUT_PATH"

# Replace module name: module model_mod -> module {model}_model_mod
sed -i.bak "s/^module model_mod$/module ${MODEL_NAME}_model_mod/g" "$OUTPUT_PATH"
sed -i.bak "s/^end module model_mod$/end module ${MODEL_NAME}_model_mod/g" "$OUTPUT_PATH"

# For each routine, add prefix to:
# 1. Function/subroutine definitions
# 2. Public declarations
# 3. Calls within the module (if any)
for routine in "${ROUTINES[@]}"; do
  # Replace subroutine/function definitions
  sed -i.bak "s/\(^\s*\)\(subroutine\|function\)\s\+${routine}\s*(/\1\2 ${MODEL_NAME}_${routine}(/g" "$OUTPUT_PATH"
  sed -i.bak "s/\(^\s*end\s\+\)\(subroutine\|function\)\s\+${routine}\s*$/\1\2 ${MODEL_NAME}_${routine}/g" "$OUTPUT_PATH"
  
  # Replace in public declarations
  sed -i.bak "s/\(public\s*::\s*\)${routine}\([\s,&]\)/\1${MODEL_NAME}_${routine}\2/g" "$OUTPUT_PATH"
done

# Clean up backup files
rm -f "${OUTPUT_PATH}.bak"

echo "Preprocessing complete!"
echo "Module renamed to: ${MODEL_NAME}_model_mod"
echo "All public routines prefixed with: ${MODEL_NAME}_"
