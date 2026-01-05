# WRF-DART Python Implementation

Modern Python implementation of WRF-DART ensemble data assimilation workflow with Slurm job arrays and native dependency management.

## Features

- ✅ Native Slurm job arrays for parallel ensemble operations
- ✅ Job dependency chains (no polling loops)
- ✅ YAML-based configuration with validation
- ✅ Comprehensive test suite (unit + integration)
- ✅ Dry-run mode for testing without HPC execution
- ✅ Structured logging and error handling
- ✅ Mock scheduler for local development

## Installation

```bash
cd wrf_dart_py
pip install -e .
```

## Quick Start

### 1. Configure Experiment

Edit `config/experiment.yaml`:

```yaml
experiment:
  name: "my_experiment"
  start_date: "2017-04-27T06:00:00"
  end_date: "2017-04-27T12:00:00"

ensemble:
  size: 50

paths:
  base_dir: "/glade/scratch/${USER}/wrf_dart"
  dart_dir: "/glade/work/${USER}/DART"

batch:
  account: "YOUR_ACCOUNT"
```

### 2. Run Single Cycle (Dry Run)

```bash
python scripts/run_cycle.py \
    --config config/experiment.yaml \
    --date 2017042706 \
    --dry-run
```

### 3. Run Single Cycle (Real)

```bash
python scripts/run_cycle.py \
    --config config/experiment.yaml \
    --date 2017042706
```

### 4. Run Multi-Cycle Chain

```bash
python scripts/submit_cycle_chain.py \
    --config config/experiment.yaml
```

## Project Structure

```
wrf_dart_py/
├── config/               # Configuration files
├── src/wrf_dart/        # Main package
│   ├── core/            # Core orchestration logic
│   ├── jobs/            # Individual job implementations
│   └── utils/           # Utilities
├── scripts/             # CLI entry points
├── tests/               # Test suite
└── docs/                # Documentation
```

## Development

### Run Tests

```bash
# All tests
pytest

# With coverage
pytest --cov=wrf_dart --cov-report=html

# Specific test
pytest tests/unit/test_job_scheduler.py
```

### Code Style

```bash
# Format code
black src/ tests/

# Check types
mypy src/

# Lint
pylint src/wrf_dart/
```

## Documentation

See [WRF_DART_DESIGN.md](../WRF_DART_DESIGN.md) for detailed design documentation.

## License

Copyright UCAR. See LICENSE file.
