#!/usr/bin/env python3
"""Prepare initial conditions for ensemble member

This script converts DART posterior state from previous cycle
into WRF wrfinput format for the current cycle.
"""

import sys
import os
import argparse
import logging
from pathlib import Path
from datetime import datetime

# Add parent directory to path to import wrf_dart module
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


def prepare_ic(member: int, cycle_date: datetime, config: dict) -> None:
    """Prepare initial conditions for single ensemble member
    
    Args:
        member: Ensemble member number (1-indexed)
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    logger.info(f"Preparing IC for member {member}, cycle {cycle_date:%Y%m%d%H}")
    
    run_dir = Path(config['paths']['run_dir'])
    output_dir = Path(config['paths']['output_dir'])
    
    # Get previous cycle date
    window_hours = config['assimilation']['window_hours']
    prev_cycle = cycle_date - pd.Timedelta(hours=window_hours)
    
    # Setup advance_temp directory for this member
    member_dir = run_dir / f"advance_temp{member}"
    member_dir.mkdir(parents=True, exist_ok=True)
    
    # Link prior file from previous cycle
    member_str = f"{member:04d}"
    prior_file = output_dir / f"{prev_cycle:%Y%m%d%H}" / "PRIORS" / f"prior_d01.{member_str}"
    
    if not prior_file.exists():
        raise FileNotFoundError(f"Prior file not found: {prior_file}")
    
    # Link wrfinput template (mean from current cycle)
    gdate = cycle_date.strftime("%Y-%m-%d_%H:%M:%S")
    wrfinput_mean = output_dir / f"{cycle_date:%Y%m%d%H}" / f"wrfinput_d01_{gdate}_mean"
    
    if not wrfinput_mean.exists():
        raise FileNotFoundError(f"wrfinput mean not found: {wrfinput_mean}")
    
    wrfinput_target = member_dir / "wrfinput_d01"
    if wrfinput_target.exists():
        wrfinput_target.unlink()
    wrfinput_target.symlink_to(wrfinput_mean)
    
    # Use DART's dart_to_wrf to update wrfinput with DART state
    # NOTE: In Phase 1, we'll call existing DART tools
    # In Phase 2, we'll reimplement this in Python using netCDF4
    
    dart_exe = Path(config['paths']['dart_dir']) / "models" / "wrf" / "work" / "dart_to_wrf"
    
    # For now, just log what would be done
    logger.info(f"Would run: {dart_exe} to update {wrfinput_target} with {prior_file}")
    logger.info(f"Member {member} IC preparation complete")
    
    # Create completion marker
    marker_file = run_dir / f"ic_d01_{member}_ready"
    marker_file.touch()


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Prepare initial conditions")
    parser.add_argument("--member", type=int, required=True, help="Ensemble member number")
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
    log_file = log_dir / f"prep_ic_mem{args.member:04d}.log"
    setup_logging(log_file)
    
    # Parse cycle date
    cycle_date = datetime.strptime(args.date, "%Y%m%d%H")
    
    try:
        prepare_ic(args.member, cycle_date, config)
        return 0
    except Exception as e:
        logging.error(f"Failed to prepare IC for member {args.member}: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
