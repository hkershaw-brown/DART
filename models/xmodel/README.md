# Multi-Model DART Support (xmodel)

## Overview

The `xmodel` directory provides infrastructure for compiling multiple DART model_mod files into a single executable. This allows for multi-model data assimilation where observations can be assimilated into multiple models simultaneously.

## Design

### Key Components

1. **preprocess_model_mod.sh** - Preprocesses model_mod.f90 files to add model-specific prefixes
2. **assim_model_mod.f90** - Multi-model version that wraps multiple model_mods
3. **quickbuild.sh** - Build script that handles multiple models

### How It Works

1. Each model's `model_mod.f90` is preprocessed to rename:
   - The module name: `model_mod` → `{model}_model_mod`
   - All public routines: `routine_name` → `{model}_routine_name`
   
2. The multi-model `assim_model_mod.f90`:
   - Imports all model_mods with renamed interfaces
   - Tracks state vector indices for each model
   - Routes calls to the appropriate model_mod based on state index
   - Combines outputs from multiple models

3. The build system:
   - Preprocesses each model's model_mod.f90
   - Sets preprocessor flags for enabled models
   - Compiles all sources together

## Quick Start

### 1. Configure Models

Edit `work/quickbuild.sh` and modify the `MODELS` array:

```bash
# Include cam-fv and wrf
MODELS=(cam-fv wrf)

# Or include different models
MODELS=(lorenz_96 lorenz_63)
```

### 2. Add Model Mappings

If adding a new model, add its short name mapping:

```bash
declare -A MODEL_SHORT_NAMES
MODEL_SHORT_NAMES["cam-fv"]="camfv"
MODEL_SHORT_NAMES["wrf"]="wrf"
MODEL_SHORT_NAMES["my-new-model"]="mynew"  # Add new mapping
```

### 3. Build

```bash
cd $DART/models/xmodel/work
./quickbuild.sh
```

## Configuration Details

### Selecting Models

The models to include are specified in the `MODELS` array in `quickbuild.sh`:

```bash
MODELS=(cam-fv wrf)  # Default: cam-fv and wrf
```

You can include any number of models (not limited to 2):

```bash
MODELS=(cam-fv wrf lorenz_96)  # Three models
```

### Model Short Names

Each model needs a short name for variable prefixes. These are defined in the `MODEL_SHORT_NAMES` associative array:

```bash
MODEL_SHORT_NAMES["cam-fv"]="camfv"   # directory name -> short name
MODEL_SHORT_NAMES["wrf"]="wrf"
```

The short name should be:
- Lowercase
- No special characters (will be used in variable names)
- Unique across all models

### Location Module

All models must be compatible with the same location module:

```bash
LOCATION=threed_sphere  # Set in quickbuild.sh
```

### Extra Dependencies

If a model requires additional source files, add them in the loop:

```bash
for model in "${MODELS[@]}"; do
  case $model in
    cam-fv)
      EXTRA="$EXTRA $DART/models/cam-common-code"
      ;;
    my-model)
      EXTRA="$EXTRA $DART/models/my-model-support"
      ;;
  esac
done
```

## File Structure

```
models/xmodel/
├── README.md                 # This file
├── QUICKSTART.md            # Quick start guide (5 steps)
├── SUMMARY.md               # Implementation summary
├── assim_model_mod.f90      # Multi-model assim_model_mod
└── work/
    ├── quickbuild.sh         # Main build script
    ├── model_config.sh       # Model selection configuration
    ├── preprocess_model_mod.sh  # Model_mod preprocessing script
    ├── verify_setup.sh       # Pre-build verification
    ├── show_config.sh        # Display current configuration
    └── preprocessed/         # Generated during build
        ├── camfv_model_mod.f90  # Preprocessed cam-fv model_mod
        └── wrf_model_mod.f90    # Preprocessed wrf model_mod
```

## Utility Scripts

The `work/` directory contains several helper scripts:

- **quickbuild.sh** - Main build script (builds all executables)
- **model_config.sh** - Configuration file (edit this to select models)
- **verify_setup.sh** - Tests configuration before building
- **show_config.sh** - Displays current configuration
- **preprocess_model_mod.sh** - Preprocesses individual model_mod files (called by quickbuild.sh)

## Adding a New Model

To add a new model to the multi-model system:

1. **Verify compatibility**: Ensure the model uses a compatible location module

2. **Add to quickbuild.sh**:
   ```bash
   # Add to MODELS array
   MODELS=(cam-fv wrf mynewmodel)
   
   # Add short name mapping
   MODEL_SHORT_NAMES["mynewmodel"]="mnm"
   
   # Add any extra dependencies if needed
   case $model in
     mynewmodel)
       EXTRA="$EXTRA $DART/models/mynewmodel/support"
       ;;
   esac
   ```

3. **Add to assim_model_mod.f90**:
   ```fortran
   #ifdef USE_MNM
   use mnm_model_mod, only : &
       mnm_get_model_size => get_model_size, &
       mnm_static_init_model => static_init_model, &
       ! ... other interfaces
   #endif
   ```
   
   Then add initialization code in `static_init_assim_model()`:
   ```fortran
   #ifdef USE_MNM
   num_models = num_models + 1
   #endif
   
   ! ... later in the routine:
   #ifdef USE_MNM
   model_idx = model_idx + 1
   model_names(model_idx) = 'mnm'
   call mnm_static_init_model()
   model_sizes(model_idx) = mnm_get_model_size()
   model_offsets(model_idx) = total_model_size + 1
   total_model_size = total_model_size + model_sizes(model_idx)
   #endif
   ```

4. **Update stub routines**: Add handling for the new model in routines like:
   - `get_state_meta_data()`
   - `get_model_time_step()`
   - Other model-specific routines

5. **Build and test**:
   ```bash
   cd $DART/models/xmodel/work
   ./quickbuild.sh
   ```

## Current Limitations

### Not Yet Implemented

The following features are not yet fully implemented in the multi-model system:

1. **Model advance** (`adv_1step`) - Advancing multiple models simultaneously
2. **Forward operator** (`interpolate`) - Needs to route obs to correct model
3. **Perturbations** (`pert_model_copies`) - Perturbing multiple model states
4. **Get close** (`get_close_obs`, `get_close_state`) - Spatial localization across models
5. **Vertical conversion** - Converting between vertical coordinates

These are currently stubs that return errors. They need to be implemented based on specific multi-model requirements.

### Design Considerations

When implementing these features, consider:

1. **Which model handles which observations?**
   - Based on observation location?
   - Based on observation type?
   - Based on user configuration?

2. **How do models interact?**
   - Are they independent?
   - Do they share state variables?
   - Do they operate on the same grid?

3. **Localization across models**
   - Should observations in one model affect another?
   - How to handle different model resolutions?

## Example: Building with cam-fv and wrf

```bash
cd $DART/models/xmodel/work

# Default configuration includes cam-fv and wrf
./quickbuild.sh

# The build process will:
# 1. Preprocess models/cam-fv/model_mod.f90 -> work/preprocessed/camfv_model_mod.f90
# 2. Preprocess models/wrf/model_mod.f90 -> work/preprocessed/wrf_model_mod.f90
# 3. Create .cppdefs with -DUSE_CAMFV -DUSE_WRF
# 4. Compile all sources
# 5. Build executables: filter, perfect_model_obs, etc.
```

## Testing

To verify the multi-model build:

1. Check that preprocessing creates renamed modules:
   ```bash
   ls work/preprocessed/
   # Should show: camfv_model_mod.f90  wrf_model_mod.f90
   ```

2. Check preprocessor definitions:
   ```bash
   cat work/.cppdefs
   # Should show: -DUSE_CAMFV -DUSE_WRF
   ```

3. Run a test executable:
   ```bash
   ./model_mod_check
   # Should initialize both models and report their sizes
   ```

## Troubleshooting

### Problem: "No short name mapping for model"

**Solution**: Add the model to the `MODEL_SHORT_NAMES` array in quickbuild.sh

### Problem: "Cannot find model_mod.f90"

**Solution**: Verify the model name matches the directory name in `$DART/models/`

### Problem: Compilation errors about undefined symbols

**Solution**: 
- Check that `.cppdefs` has the correct `-DUSE_*` flags
- Verify assim_model_mod.f90 has `#ifdef` blocks for your models
- Ensure preprocessed model_mod files were created

### Problem: Location module incompatibility

**Solution**: All models must use the same location module. Check each model's requirements.

## Future Enhancements

Potential improvements:

1. **Configuration file**: Move model selection to a namelist instead of editing quickbuild.sh
2. **Automatic model detection**: Scan for available models
3. **Model coupling**: Support for coupled model systems
4. **Split states**: Support for models on different grids/domains
5. **Selective assimilation**: Control which obs go to which models
6. **Complete implementation**: Finish stub routines for full functionality

## Contact

For questions or issues with the multi-model system, contact the DART development team.
