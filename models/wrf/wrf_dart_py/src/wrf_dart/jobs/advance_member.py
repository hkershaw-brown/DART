#!/usr/bin/env python3
"""Advance single ensemble member forward in time using WRF

This script runs WRF for one ensemble member and converts output to DART format.
"""

import sys
import os
import subprocess
import logging
from pathlib import Path
from datetime import datetime
import argparse

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from wrf_dart.utils.config import load_config


def setup_logging(log_file: Path) -> None:
    """Setup logging configuration"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )


def advance_member(member: int, cycle_date: datetime, config: dict) -> None:
    """Advance ensemble member using WRF
    
    Args:
        member: Ensemble member number (1-indexed)
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    logger.info(f"Advancing member {member} from cycle {cycle_date:%Y%m%d%H}")
    
    run_dir = Path(config['paths']['run_dir'])
    member_dir = run_dir / f"advance_temp{member}"
    
    # Mark start time
    start_marker = run_dir / f"start_member_{member}"
    with open(start_marker, 'w') as f:
        f.write(str(int(datetime.now().timestamp())))
    
    # Change to member directory
    os.chdir(member_dir)
    
    # Setup WRF namelist
    setup_wrf_namelist(member, cycle_date, config)
    
    # Link boundary conditions
    link_boundary_conditions(member, cycle_date, config)
    
    # Run WRF
    run_wrf(member, config)
    
    # Convert WRF output to DART prior format
    convert_to_dart(member, cycle_date, config)
    
    # Archive outputs
    archive_outputs(member, cycle_date, config)
    
    # Mark completion
    done_marker = run_dir / f"done_member_{member}"
    done_marker.touch()
    
    logger.info(f"Member {member} advancement complete")


def setup_wrf_namelist(member: int, cycle_date: datetime, config: dict) -> None:
    """Setup WRF namelist for this member
    
    Args:
        member: Ensemble member number
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    logger.info(f"Setting up WRF namelist for member {member}")
    
    # In Phase 1, we'd copy and modify namelist.input
    # In Phase 2, we'd use a Python namelist parser/generator
    
    template = Path(config['wrf']['namelist_template'])
    target = Path.cwd() / "namelist.input"
    
    # For now, just copy template
    # TODO: Modify for correct times, member-specific perturbations, etc.
    import shutil
    shutil.copy(template, target)


def link_boundary_conditions(member: int, cycle_date: datetime, config: dict) -> None:
    """Link boundary condition files
    
    Args:
        member: Ensemble member number
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    output_dir = Path(config['paths']['output_dir']) / f"{cycle_date:%Y%m%d%H}"
    
    # Get next cycle date for boundary conditions
    window_hours = config['assimilation']['window_hours']
    next_cycle = cycle_date + pd.Timedelta(hours=window_hours)
    
    gdate_next = next_cycle.strftime("%Y-%m-%d_%H:%M:%S")
    wrfbdy_file = output_dir / f"wrfbdy_d01_{gdate_next}_mean"
    
    if not wrfbdy_file.exists():
        raise FileNotFoundError(f"Boundary file not found: {wrfbdy_file}")
    
    target = Path.cwd() / "wrfbdy_d01"
    if target.exists():
        target.unlink()
    target.symlink_to(wrfbdy_file)
    
    logger.info("Boundary conditions linked")


def run_wrf(member: int, config: dict) -> None:
    """Execute WRF
    
    Args:
        member: Ensemble member number
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    logger.info(f"Launching WRF for member {member}")
    
    wrf_exe = Path(config['wrf']['executables']['wrf'])
    if not wrf_exe.exists():
        raise FileNotFoundError(f"WRF executable not found: {wrf_exe}")
    
    ntasks = config['batch']['advance']['ntasks_per_node']
    
    cmd = ["mpiexec", "-n", str(ntasks), str(wrf_exe)]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        logger.error(f"WRF failed for member {member}")
        logger.error(f"Check rsl.error.0000 for details")
        raise RuntimeError(f"WRF execution failed for member {member}")
    
    logger.info(f"WRF completed for member {member}")


def convert_to_dart(member: int, cycle_date: datetime, config: dict) -> None:
    """Convert WRF output to DART prior format
    
    Args:
        member: Ensemble member number
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    logger.info(f"Converting WRF output to DART format for member {member}")
    
    # Use DART's wrf_to_dart tool
    # TODO: In Phase 2, reimplement in Python
    
    member_str = f"{member:04d}"
    dart_exe = Path(config['paths']['dart_dir']) / "models" / "wrf" / "work" / "wrf_to_dart"
    
    logger.info(f"Would run: {dart_exe} to create prior_d01.{member_str}")


def archive_outputs(member: int, cycle_date: datetime, config: dict) -> None:
    """Archive member outputs
    
    Args:
        member: Ensemble member number
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    output_dir = Path(config['paths']['output_dir']) / f"{cycle_date:%Y%m%d%H}"
    
    # Create output directories
    (output_dir / "PRIORS").mkdir(parents=True, exist_ok=True)
    (output_dir / "WRFIN").mkdir(parents=True, exist_ok=True)
    (output_dir / "logs").mkdir(parents=True, exist_ok=True)
    
    logger.info(f"Archiving outputs for member {member}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Advance ensemble member")
    parser.add_argument("--member", type=int, help="Ensemble member number")
    parser.add_argument("--date", type=str, required=True, help="Cycle date (YYYYMMDDHH)")
    parser.add_argument("--config", type=str, required=True, help="Configuration file path")
    
    args = parser.parse_args()
    
    # Get member from Slurm array task ID if not provided
    if args.member is None:
        args.member = int(os.environ.get('SLURM_ARRAY_TASK_ID', 1))
    
    # Load configuration
    config = load_config(args.config)
    
    # Setup logging
    log_dir = Path(config['paths']['run_dir']) / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"advance_mem{args.member:04d}.log"
    setup_logging(log_file)
    
    # Parse cycle date
    cycle_date = datetime.strptime(args.date, "%Y%m%d%H")
    
    try:
        advance_member(args.member, cycle_date, config)
        return 0
    except Exception as e:
        logging.error(f"Failed to advance member {args.member}: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
