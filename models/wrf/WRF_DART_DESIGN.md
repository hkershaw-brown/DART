# WRF-DART Shell Scripts Design & Modernization Plan

**Author:** Helen Kershaw  
**Date:** January 5, 2026  
**Purpose:** Document existing shell script architecture and design for Python reimplementation

---

## Table of Contents

1. [Current Architecture](#current-architecture)
2. [Shell Script Components](#shell-script-components)
3. [Data Flow](#data-flow)
4. [Synchronization Mechanisms](#synchronization-mechanisms)
5. [Python Modernization Design](#python-modernization-design)
6. [Testing Strategy](#testing-strategy)
7. [Migration Path](#migration-path)

---

## Current Architecture

### Overview

The WRF-DART system implements a cycling ensemble data assimilation workflow using csh shell scripts. The system coordinates:

- **Ensemble generation** (multiple WRF model instances)
- **Data assimilation** (DART filter)
- **Model advancement** (WRF forecasts)
- **Diagnostics and archiving**

### Main Components

| Script | Purpose | Parallelization |
|--------|---------|-----------------|
| `driver.csh` | Master orchestrator, cycling loop | Serial |
| `param.csh` | Configuration parameters | N/A |
| `prep_ic.csh` | Prepare initial conditions | Per-member parallel |
| `assimilate.csh` | Run DART filter | Single job |
| `assim_advance.csh` | Wrapper for model advance | Per-member parallel |
| `new_advance_model.csh` | Execute WRF and convert output | Per-member |
| `diagnostics_obs.csh` | Compute observation-space diagnostics | Background job |

---

## Shell Script Components

### 1. driver.csh - Main Orchestrator

**Responsibilities:**
- Cycle through assimilation windows
- Submit jobs to batch scheduler
- Monitor job completion via polling
- Manage file I/O between stages
- Handle restarts and error conditions

**Key Workflow:**
```
while (cycling):
    1. Check input files exist
    2. Submit prep_ic jobs (parallel)
    3. Poll for prep_ic completion
    4. Submit assimilate job (single)
    5. Poll for filter completion
    6. Submit assim_advance jobs (parallel)
    7. Poll for advance completion
    8. Archive outputs
    9. Increment cycle time
```

**Platform Support:**
- LSF (`bsub`)
- PBS/Slurm (`qsub`)

**Synchronization Pattern:**
```csh
# Submit jobs in loop
set n = 1
while ( $n <= $NUM_ENS )
    qsub job_${n}.csh
    @ n++
end

# Poll for completion
while ( ! -e done_file )
    sleep 10
    check_timeout()
end
```

### 2. prep_ic.csh - Initial Condition Preparation

**Purpose:** Convert DART posterior from previous cycle into WRF wrfinput format

**Process:**
1. Link prior ensemble member file
2. Extract DART state and update wrfinput template
3. Create signal file when complete

**File Markers:**
- `ic_d${domain}_${member}_ready` - Completion signal

### 3. assimilate.csh - DART Filter Execution

**Purpose:** Run the DART filter executable for data assimilation

**Process:**
1. Setup MPI environment
2. Run filter executable
3. Compute analysis increments using ncdiff/ncks
4. Archive diagnostics
5. Handle adaptive inflation files

**File Markers:**
- `filter_started` - Start timestamp
- `filter_done` - Completion signal

**Key Outputs:**
- `obs_seq.final` - Assimilated observations
- `preassim_mean.nc`, `postassim_mean.nc` - Prior/posterior ensemble means
- `analysis_increment.nc` - Analysis update
- Inflation restart files

### 4. assim_advance.csh / new_advance_model.csh - Model Integration

**Purpose:** Advance ensemble members forward in time using WRF

**Process:**
1. Setup WRF namelist for forecast length
2. Link boundary conditions
3. Run WRF (via mpirun)
4. Convert WRF output to DART prior format
5. Archive outputs

**File Markers:**
- `start_member_${n}` - Start timestamp
- `done_member_${n}` - Completion signal

**Retry Logic:**
- Monitors walltime
- Resubmits failed members (max 2 attempts)
- Aborts cycle if member repeatedly fails

---

## Data Flow

### Directory Structure

```
OUTPUT_DIR/${date}/
├── obs_seq.out              # Input observations
├── obs_seq.final            # Assimilated observations
├── preassim_mean.nc         # Prior ensemble mean
├── postassim_mean.nc        # Posterior ensemble mean
├── analysis_increment.nc    # Analysis update
├── wrfinput_d01_*_mean      # WRF initial conditions (mean)
├── wrfbdy_d01_*_mean        # WRF boundary conditions
├── Inflation_input/         # Adaptive inflation files
├── WRFIN/                   # Per-member wrfinput files
├── PRIORS/                  # Per-member DART prior files
└── logs/                    # Job logs and diagnostics

RUN_DIR/
├── advance_temp${n}/        # Per-member WRF run directory
├── input.nml                # DART namelist
├── filter_restart_d01.*     # DART state vectors
└── [temporary files]
```

### File Naming Conventions

```
wrfinput_d${domain}_${YYYYMMDD}_${HHMMSS}_mean
prior_d${domain}.${member_4digit}
filter_restart_d${domain}.${member_4digit}
```

---

## Synchronization Mechanisms

### 1. File-Based Semaphores

**Pattern:** Create empty files to signal job completion
```csh
# Producer
touch done_member_${n}

# Consumer (polling loop)
while ( ! -e done_member_${n} )
    sleep 5
end
```

**Issues:**
- High filesystem I/O from polling
- No native timeout handling
- Race conditions possible

### 2. Time-Based Timeouts

```csh
set start_time = `head -1 filter_started`
set current_time = `date +%s`
@ elapsed = $current_time - $start_time
if ( $elapsed > $threshold ) then
    # Timeout - resubmit or abort
endif
```

### 3. Queue Monitoring

```csh
if ( `qstat | grep job_name | wc -l` == 0 ) then
    # Job disappeared from queue - resubmit
    qsub job.csh
endif
```

---

## Python Modernization Design

### Goals

1. **Eliminate polling** - Use native Slurm job dependencies
2. **Use job arrays** - Parallelize ensemble operations efficiently
3. **Improve testability** - Modular, mockable components
4. **Better error handling** - Structured logging, graceful failures
5. **Configuration management** - YAML-based, validated configs
6. **Maintainability** - Type hints, documentation, PEP 8

### Proposed Architecture

```
wrf_dart_py/
├── config/
│   ├── experiment.yaml           # User configuration
│   ├── defaults.yaml             # Default settings
│   └── schemas/
│       └── experiment_schema.yaml
├── src/
│   └── wrf_dart/
│       ├── __init__.py
│       ├── core/
│       │   ├── __init__.py
│       │   ├── cycle_manager.py       # Main orchestrator
│       │   ├── job_scheduler.py       # Batch system abstraction
│       │   ├── state_manager.py       # DART state handling
│       │   └── file_manager.py        # I/O operations
│       ├── jobs/
│       │   ├── __init__.py
│       │   ├── prepare_ic.py          # IC preparation
│       │   ├── run_filter.py          # Filter execution
│       │   └── advance_member.py      # Model advancement
│       └── utils/
│           ├── __init__.py
│           ├── config.py              # Config loading/validation
│           └── logging_config.py      # Logging setup
├── scripts/
│   ├── run_cycle.py                   # CLI entry point
│   └── submit_cycle_chain.py          # Multi-cycle submission
├── tests/
│   ├── __init__.py
│   ├── conftest.py                    # Pytest fixtures
│   ├── unit/
│   │   ├── test_job_scheduler.py
│   │   ├── test_cycle_manager.py
│   │   └── test_config.py
│   ├── integration/
│   │   └── test_workflow.py
│   └── fixtures/
│       ├── mock_config.yaml
│       └── sample_data/
├── pyproject.toml
├── setup.py
├── README.md
└── requirements.txt
```

### Key Design Patterns

#### 1. Job Scheduler Abstraction

```python
from abc import ABC, abstractmethod
from typing import Optional, List
from dataclasses import dataclass

@dataclass
class JobConfig:
    """Configuration for batch job submission"""
    name: str
    script: str
    queue: str
    nodes: int
    ntasks: int
    walltime: str
    account: str
    dependency: Optional[str] = None
    array: Optional[str] = None
    
class JobScheduler(ABC):
    """Abstract interface for batch schedulers"""
    
    @abstractmethod
    def submit_job(self, config: JobConfig) -> str:
        """Submit job, return job ID"""
        pass
    
    @abstractmethod
    def submit_array(self, config: JobConfig, array_size: int) -> str:
        """Submit job array, return job ID"""
        pass
    
    @abstractmethod
    def cancel_job(self, job_id: str) -> None:
        """Cancel running job"""
        pass

class SlurmScheduler(JobScheduler):
    """Slurm implementation"""
    
    def submit_job(self, config: JobConfig) -> str:
        cmd = ["sbatch"]
        cmd.extend(["--job-name", config.name])
        cmd.extend(["--nodes", str(config.nodes)])
        cmd.extend(["--ntasks", str(config.ntasks)])
        cmd.extend(["--time", config.walltime])
        cmd.extend(["--account", config.account])
        
        if config.dependency:
            cmd.extend(["--dependency", config.dependency])
        
        cmd.append(config.script)
        
        result = subprocess.run(
            cmd, 
            capture_output=True, 
            text=True, 
            check=True
        )
        return self._parse_job_id(result.stdout)
    
    def submit_array(self, config: JobConfig, array_size: int) -> str:
        config.array = f"1-{array_size}"
        return self.submit_job(config)
```

#### 2. Cycle Manager

```python
from pathlib import Path
from datetime import datetime, timedelta
import logging

class CycleManager:
    """Manages single assimilation cycle"""
    
    def __init__(self, config: dict, scheduler: JobScheduler, dry_run: bool = False):
        self.config = config
        self.scheduler = scheduler
        self.dry_run = dry_run
        self.logger = logging.getLogger(__name__)
        
    def run_cycle(self, cycle_date: datetime) -> str:
        """Execute complete assimilation cycle
        
        Returns job ID of final advance array
        """
        self.logger.info(f"Starting cycle for {cycle_date}")
        
        # Phase 1: Prepare initial conditions (parallel)
        prep_job_id = self._submit_prep_ic(cycle_date)
        
        # Phase 2: Run filter (depends on prep completion)
        filter_job_id = self._submit_filter(
            cycle_date, 
            dependency=f"afterok:{prep_job_id}"
        )
        
        # Phase 3: Advance ensemble (depends on filter)
        advance_job_id = self._submit_advance(
            cycle_date,
            dependency=f"afterok:{filter_job_id}"
        )
        
        # Phase 4: Diagnostics (runs concurrently with advance)
        diag_job_id = self._submit_diagnostics(
            cycle_date,
            dependency=f"afterok:{filter_job_id}"
        )
        
        return advance_job_id
    
    def _submit_prep_ic(self, cycle_date: datetime) -> str:
        """Submit IC preparation job array"""
        config = JobConfig(
            name=f"prep_ic_{cycle_date:%Y%m%d%H}",
            script=self._get_script_path("prepare_ic.py"),
            queue=self.config['batch']['ic_prep']['queue'],
            nodes=1,
            ntasks=1,
            walltime=self.config['batch']['ic_prep']['walltime'],
            account=self.config['batch']['account']
        )
        
        if self.dry_run:
            self.logger.info(f"Would submit: {config.name}")
            return "dry_run_job_id"
        
        return self.scheduler.submit_array(
            config, 
            self.config['ensemble']['size']
        )
```

#### 3. Configuration Management

```yaml
# experiment.yaml
experiment:
  name: "wrf_dart_conus"
  start_date: "2017-04-27T06:00:00"
  end_date: "2017-04-27T12:00:00"
  
ensemble:
  size: 50
  
assimilation:
  window_hours: 6
  num_domains: 1
  adaptive_inflation: true
  
paths:
  base_dir: "/glade/scratch/${USER}/wrf_dart"
  output_dir: "${base_dir}/output"
  run_dir: "${base_dir}/rundir"
  dart_dir: "/glade/work/${USER}/DART"
  
batch:
  scheduler: "slurm"
  account: "P86850054"
  
  ic_prep:
    queue: "main"
    walltime: "00:05:00"
    
  filter:
    queue: "main"
    nodes: 2
    ntasks_per_node: 64
    walltime: "00:35:00"
    
  advance:
    queue: "main"
    nodes: 1
    ntasks_per_node: 128
    walltime: "00:20:00"
```

#### 4. Job Scripts

**prepare_ic.py:**
```python
#!/usr/bin/env python3
"""Prepare initial conditions for single ensemble member"""

import sys
import argparse
from pathlib import Path
import netCDF4 as nc
from wrf_dart.core.state_manager import StateManager
from wrf_dart.utils.config import load_config

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--member", type=int, required=True)
    parser.add_argument("--date", type=str, required=True)
    parser.add_argument("--config", type=str, required=True)
    args = parser.parse_args()
    
    config = load_config(args.config)
    state_mgr = StateManager(config)
    
    # Extract DART state into wrfinput
    state_mgr.dart_to_wrf(
        member=args.member,
        date=args.date
    )

if __name__ == "__main__":
    main()
```

### Slurm Job Dependencies

Replace polling with native Slurm dependencies:

| Old Pattern | New Pattern |
|-------------|-------------|
| Loop submit + poll | `sbatch --array=1-50` |
| File semaphores | `--dependency=afterok:job_id` |
| Manual resubmit | `--dependency=afterany:job_id` |
| Queue monitoring | Slurm handles automatically |

**Example Dependency Chain:**
```bash
# Submit prep array
PREP_ID=$(sbatch --array=1-50 --parsable prep_ic.sh)

# Filter depends on all prep jobs
FILTER_ID=$(sbatch --dependency=afterok:${PREP_ID} --parsable run_filter.sh)

# Advance array depends on filter
ADVANCE_ID=$(sbatch --array=1-50 --dependency=afterok:${FILTER_ID} advance.sh)
```

---

## Testing Strategy

### 1. Unit Tests

**Test Components in Isolation:**
```python
def test_slurm_job_id_parsing():
    """Test parsing Slurm job ID from sbatch output"""
    output = "Submitted batch job 12345678\n"
    scheduler = SlurmScheduler()
    assert scheduler._parse_job_id(output) == "12345678"

def test_dependency_string_builder():
    """Test building Slurm dependency string"""
    jobs = ["123", "124", "125"]
    dep_str = build_dependency_string(jobs, "afterok")
    assert dep_str == "afterok:123:124:125"

def test_config_validation():
    """Test configuration schema validation"""
    config = load_config("tests/fixtures/invalid_config.yaml")
    with pytest.raises(ValidationError):
        validate_config(config)
```

### 2. Integration Tests

**Test Workflow with Mock Scheduler:**
```python
class MockScheduler(JobScheduler):
    """Mock scheduler for testing without HPC"""
    
    def __init__(self):
        self.submitted_jobs = []
        self.job_counter = 0
        
    def submit_job(self, config: JobConfig) -> str:
        self.job_counter += 1
        job_id = f"mock_{self.job_counter}"
        self.submitted_jobs.append({
            'id': job_id,
            'config': config
        })
        return job_id

def test_full_cycle_workflow():
    """Test complete assimilation cycle"""
    scheduler = MockScheduler()
    config = load_config("tests/fixtures/mock_config.yaml")
    manager = CycleManager(config, scheduler, dry_run=True)
    
    cycle_date = datetime(2017, 4, 27, 6)
    final_job = manager.run_cycle(cycle_date)
    
    # Verify job submission order and dependencies
    assert len(scheduler.submitted_jobs) >= 3
    
    prep_job = scheduler.submitted_jobs[0]
    assert "prep_ic" in prep_job['config'].name
    assert prep_job['config'].array == "1-50"
    
    filter_job = scheduler.submitted_jobs[1]
    assert "filter" in filter_job['config'].name
    assert prep_job['id'] in filter_job['config'].dependency
    
    advance_job = scheduler.submitted_jobs[2]
    assert "advance" in advance_job['config'].name
    assert filter_job['id'] in advance_job['config'].dependency
```

### 3. Dry-Run Mode

**Test on HPC Without Execution:**
```python
# Run with dry_run=True
python run_cycle.py --config experiment.yaml --date 2017042706 --dry-run

# Output:
# Would submit: prep_ic_2017042706 (array=1-50)
# Would submit: filter_2017042706 (depends on: prep_ic_2017042706)
# Would submit: advance_2017042706 (array=1-50, depends on: filter_2017042706)
```

### 4. Fixture Data

Create minimal test datasets:
```
tests/fixtures/
├── mock_config.yaml
├── input.nml.template
├── sample_wrfinput_d01.nc (small domain)
├── sample_obs_seq.out (few obs)
└── sample_prior_d01.0001
```

### 5. Continuous Integration

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
        with:
          python-version: '3.10'
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov
      - name: Run tests
        run: pytest --cov=wrf_dart tests/
```

---

## Migration Path

### Phase 1: Python Wrapper (Weeks 1-2)

**Goal:** Replace driver.csh with Python orchestrator, keep existing shell scripts

**Implementation:**
- `cycle_manager.py` submits existing `.csh` scripts
- Use Slurm job arrays and dependencies
- Keep file-based I/O patterns
- Add logging and monitoring

**Benefits:**
- Eliminates polling loops
- Better job dependency management
- Easier debugging

**Testing:**
- Run parallel with existing system
- Compare outputs byte-for-byte

### Phase 2: Core Logic Migration (Weeks 3-6)

**Goal:** Reimplement prep_ic.csh and diagnostics in Python

**Implementation:**
- Replace `ncks`/`ncdiff` with netCDF4-python
- Direct manipulation of DART state vectors
- Parallel I/O where possible

**Benefits:**
- More efficient file operations
- Better error handling
- Cross-platform compatibility

### Phase 3: Advanced Features (Weeks 7-10)

**Goal:** Add new capabilities

**Implementation:**
- Real-time monitoring dashboard
- Automated restart/recovery
- Performance profiling
- Workflow optimization

### Phase 4: Production Deployment (Weeks 11-12)

**Goal:** Full production use

**Implementation:**
- Documentation
- User training
- Performance tuning
- Deprecate shell scripts

---

## Key Differences: Shell vs Python

| Aspect | Shell Scripts | Python Implementation |
|--------|--------------|----------------------|
| **Job submission** | Loop with serial submits | Job arrays |
| **Synchronization** | File polling (high I/O) | Native dependencies (zero I/O) |
| **Configuration** | csh variables | YAML with validation |
| **Error handling** | Exit codes, limited | Exceptions, logging, retry logic |
| **Testing** | Requires HPC | Unit tests on laptop |
| **Monitoring** | Manual log parsing | Structured logging, metrics |
| **Restart** | Manual intervention | Automated recovery |
| **Portability** | LSF/PBS specific | Scheduler abstraction |

---

## Success Metrics

### Correctness
- [ ] Bit-for-bit identical DART outputs
- [ ] All test cases pass
- [ ] Successful 7-day reanalysis

### Performance
- [ ] <5% wallclock time difference vs shell
- [ ] Reduced filesystem I/O by >90%
- [ ] Faster job throughput

### Maintainability
- [ ] >80% test coverage
- [ ] All functions documented
- [ ] PEP 8 compliant

### Usability
- [ ] Single command cycle submission
- [ ] Clear error messages
- [ ] Dry-run mode works

---

## References

- DART Documentation: https://docs.dart.ucar.edu
- Slurm Job Arrays: https://slurm.schedmd.com/job_array.html
- WRF User Guide: https://www2.mmm.ucar.edu/wrf/users/
- Python netCDF4: https://unidata.github.io/netcdf4-python/

---

## Appendix: Common Pitfalls to Avoid

### 1. Filesystem Race Conditions
**Problem:** Multiple jobs writing to same file
**Solution:** Use atomic operations, unique temp files

### 2. Job Dependency Cycles
**Problem:** Job A depends on B, B depends on A
**Solution:** Carefully validate dependency graph

### 3. Hardcoded Paths
**Problem:** Paths break when moving systems
**Solution:** All paths in config, use Path objects

### 4. Insufficient Error Context
**Problem:** Generic "Job failed" message
**Solution:** Structured logging with context

### 5. Testing Only on HPC
**Problem:** Slow development cycle
**Solution:** Mock scheduler for local testing

---

**Document Version:** 1.0  
**Last Updated:** January 5, 2026
