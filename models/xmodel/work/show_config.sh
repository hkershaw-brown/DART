#!/usr/bin/env bash

# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

#-------------------------
# Show current multi-model configuration
#-------------------------

export DART=$(git rev-parse --show-toplevel)

# Load configuration
XMODEL_DIR="$DART/models/xmodel/work"
source "$XMODEL_DIR/model_config.sh"

print_config_summary

echo "Configuration file: $XMODEL_DIR/model_config.sh"
echo ""
echo "To change configuration:"
echo "  1. Edit model_config.sh"
echo "  2. Run ./verify_setup.sh to test changes"
echo "  3. Run ./quickbuild.sh to build"
echo ""
