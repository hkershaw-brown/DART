## Multi-Model DART Implementation Summary

### Created Files and Directories

```
models/xmodel/
├── README.md                          # Comprehensive documentation
├── QUICKSTART.md                      # Quick start guide
├── assim_model_mod.f90                # Multi-model wrapper implementation
└── work/
    ├── quickbuild.sh                  # Main build script
    ├── model_config.sh                # Model selection configuration
    ├── preprocess_model_mod.sh        # Script to rename model_mod routines
    └── verify_setup.sh                # Pre-build verification script
```

### Key Features

1. **Declarative Configuration**
   - Models are selected via the `MODELS` array in `model_config.sh`
   - Not limited to 2 models - can include any number
   - Easy to add/remove models without code changes

2. **Automatic Preprocessing**
   - Each model's `model_mod.f90` is automatically renamed
   - Module name: `model_mod` → `{model}_model_mod`
   - All public routines get model-specific prefixes
   - Example: `static_init_model` → `camfv_static_init_model`

3. **Auto-Generated Multi-Model Wrapper**
   - `assim_model_mod.f90` is generated from `model_config.sh`
   - No manual editing required when adding new models
   - Automatically creates all necessary `#ifdef` blocks

4. **Conditional Compilation**
   - Uses preprocessor directives (`#ifdef USE_CAMFV`, etc.)
   - Only enabled models are compiled
   - Preprocessor flags generated automatically from configuration

5. **State Vector Management**
   - Combined state vector includes all models
   - Tracks offsets and sizes for each model
   - Routes function calls to appropriate model based on state index

### How to Use

**Basic Usage:**
```bash
cd $DART/models/xmodel/work
./verify_setup.sh      # Check configuration
./quickbuild.sh        # Build executables
```

**To Change Models:**

Edit `model_config.sh`:
```bash
# Change this line:
MODELS=(cam-fv wrf)

# To include different models:
MODELS=(lorenz_96 lorenz_63)
# or
MODELS=(cam-fv wrf lorenz_96)  # Three models
```

Then rebuild:
```bash
./quickbuild.sh
```

The system automatically generates `assim_model_mod.f90` for whatever models you specify.

**To Add a New Model:**

1. Add to `MODELS` array
2. Add short name mapping to `MODEL_SHORT_NAMES`
3. Add model-specific code to `assim_model_mod.f90` (see README.md)
4. Run `./verify_setup.sh` and `./quickbuild.sh`

### Design Pattern

The system uses a **preprocess-and-rename** pattern:

1. **Original model_mod.f90** (cam-fv example):
   ```fortran
   module model_mod
     public :: static_init_model
     subroutine static_init_model()
   ```

2. **Preprocessed camfv_model_mod.f90**:
   ```fortran
   module camfv_model_mod
     public :: camfv_static_init_model
     subroutine camfv_static_init_model()
   ```

3. **Multi-model assim_model_mod.f90**:
   ```fortran
   #ifdef USE_CAMFV
   use camfv_model_mod, only: camfv_static_init_model => static_init_model
   #endif
   
   subroutine static_init_assim_model()
     #ifdef USE_CAMFV
     call camfv_static_init_model()
     #endif
   end subroutine
   ```

### Example Configurations

**Atmosphere-only:**
```bash
MODELS=(cam-fv wrf)
LOCATION=threed_sphere
```

**Simple test models:**
```bash
MODELS=(lorenz_96 lorenz_63)
LOCATION=oned
```

**Three models:**
```bash
MODELS=(cam-fv wrf lorenz_96)
LOCATION=threed_sphere
```

### Auto-generation of assim_model_mod.f90
- ✅ Current Status

**Implemented:**
- ✅ Directory structure
- ✅ Preprocessing system
- ✅ Build infrastructure
- ✅ Configuration system
- ✅ Verification tools
- ✅ Documentation
- ✅ Basic assim_model_mod wrapper
- ✅ State vector management
- ✅ Model initialization
- ✅ Model size tracking

**Requires Implementation (Model-Specific):**
- ⚠️ Model advance (`adv_1step`)
- ⚠️ Forward operator (`interpolate`)
- ⚠️ Perturbations (`pert_model_copies`)
- ⚠️ Localization (`get_close_obs`, `get_close_state`)
- ⚠️ Vertical conversion (`convert_vertical_obs`, `convert_vertical_state`)

These stubs exist but need to be implemented based on specific multi-model requirements.

### Testing

Run the verification script to test the setup:
```bash
cd $DART/models/xmodel/work
./verify_setup.sh
```

This will:
- Validate configuration
- Test preprocessing
- Show what will be built
- Identify configuration errors

### Next Steps for Users

1. **Review Configuration**: Check `model_config.sh` settings
2. **Verify Setup**: Run `./verify_setup.sh`
3. **Build**: Run `./quickbuild.sh`
4. **Test**: Run `./model_mod_check` to verify model initialization
5. **Implement**: Add code for stub routines based on requirements
6. **Customize**: Modify for specific multi-model DA scenarios

### Documentation Files

- **QUICKSTART.md** - Quick start guide (5 steps to get running)
- **README.md** - Comprehensive documentation with examples
- **SUMMARY.md** - This file

### Support

For issues or questions:
- Check README.md "Troubleshooting" section
- Run `./verify_setup.sh` for diagnostic information
- Examine `preprocessed/` directory to see renamed files
- Check build output for specific errors
