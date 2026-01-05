# WRF-DART Python Quick Start Guide

## Installation

```bash
cd /path/to/wrf_dart_py

# Install in development mode
pip install -e .

# Or install dependencies separately
pip install -r requirements.txt

# For development
pip install -r requirements-dev.txt
```

## Configuration

1. Copy and edit the example configuration:

```bash
cp config/experiment.yaml config/my_experiment.yaml
```

2. Update paths and settings:

```yaml
experiment:
  name: "my_conus_experiment"
  start_date: "2017-04-27T06:00:00"
  end_date: "2017-04-27T18:00:00"

paths:
  base_dir: "/glade/scratch/${USER}/wrf_dart"
  dart_dir: "/glade/work/${USER}/DART"

batch:
  account: "YOUR_ACCOUNT_HERE"
```

## Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=wrf_dart --cov-report=html

# Run specific test file
pytest tests/unit/test_job_scheduler.py

# Run in verbose mode
pytest -v

# Run specific test
pytest tests/unit/test_cycle_manager.py::TestCycleManager::test_run_cycle_job_submission
```

## Usage Examples

### 1. Dry Run (Test Configuration)

```bash
python scripts/run_cycle.py \
    --config config/my_experiment.yaml \
    --date 2017042706 \
    --dry-run
```

### 2. Submit Single Cycle

```bash
python scripts/run_cycle.py \
    --config config/my_experiment.yaml \
    --date 2017042706
```

### 3. Submit Cycle Chain

```bash
python scripts/submit_cycle_chain.py \
    --config config/my_experiment.yaml
```

### 4. Submit Custom Date Range

```bash
python scripts/submit_cycle_chain.py \
    --config config/my_experiment.yaml \
    --start-date 2017042700 \
    --end-date 2017042800
```

## Development Workflow

### 1. Make Code Changes

Edit files in `src/wrf_dart/`

### 2. Run Tests

```bash
pytest
```

### 3. Check Code Style

```bash
# Format code
black src/ tests/

# Type checking
mypy src/

# Lint
pylint src/wrf_dart/
```

### 4. Test on HPC (Dry Run)

```bash
# Login to HPC
ssh casper.hpc.ucar.edu

# Navigate to project
cd /path/to/wrf_dart_py

# Test with dry run
python scripts/run_cycle.py --config config/test.yaml --date 2017042706 --dry-run
```

## Troubleshooting

### Issue: Module not found

**Solution:** Make sure you installed in development mode:
```bash
pip install -e .
```

### Issue: Configuration validation error

**Solution:** Check required fields:
```bash
python -c "from wrf_dart.utils.config import load_config; load_config('config/my_experiment.yaml')"
```

### Issue: Tests failing

**Solution:** Install test dependencies:
```bash
pip install -r requirements-dev.txt
```

## Next Steps

1. **Phase 1**: Test with existing shell scripts
   - Python submits shell script jobs
   - Verify job dependencies work
   - Compare outputs with original system

2. **Phase 2**: Migrate core logic
   - Implement Python IC preparation
   - Replace NCO tools with netCDF4-python
   - Add unit tests for new code

3. **Phase 3**: Production deployment
   - Full testing on real experiment
   - Performance tuning
   - Documentation updates

## Getting Help

- Design document: See `../WRF_DART_DESIGN.md`
- DART documentation: https://docs.dart.ucar.edu
- Report issues: Contact Helen Kershaw
