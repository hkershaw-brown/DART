#!/usr/bin/env python3
"""Run observation-space diagnostics

This script runs obs_diag to analyze observation space statistics.
"""

import sys
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


def run_diagnostics(cycle_date: datetime, config: dict) -> None:
    """Run observation diagnostics
    
    Args:
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    logger.info(f"Running diagnostics for cycle {cycle_date:%Y%m%d%H}")
    
    run_dir = Path(config['paths']['run_dir'])
    output_dir = Path(config['paths']['output_dir']) / f"{cycle_date:%Y%m%d%H}"
    
    # Link obs_seq.final
    obs_seq = output_dir / "obs_seq.final"
    if not obs_seq.exists():
        logger.warning(f"obs_seq.final not found: {obs_seq}")
        return
    
    diag_dir = output_dir / "diagnostics"
    diag_dir.mkdir(parents=True, exist_ok=True)
    
    # Run obs_diag
    obs_diag_exe = Path(config['dart']['executables']['obs_diag'])
    
    if not obs_diag_exe.exists():
        logger.warning(f"obs_diag executable not found: {obs_diag_exe}")
        return
    
    logger.info("Running obs_diag")
    # TODO: Setup obs_diag namelist, run executable
    
    logger.info("Diagnostics complete")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Run observation diagnostics")
    parser.add_argument("--date", type=str, required=True, help="Cycle date (YYYYMMDDHH)")
    parser.add_argument("--config", type=str, required=True, help="Configuration file path")
    
    args = parser.parse_args()
    
    # Load configuration
    config = load_config(args.config)
    
    # Setup logging
    log_dir = Path(config['paths']['run_dir']) / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"diagnostics_{args.date}.log"
    setup_logging(log_file)
    
    # Parse cycle date
    cycle_date = datetime.strptime(args.date, "%Y%m%d%H")
    
    try:
        run_diagnostics(cycle_date, config)
        return 0
    except Exception as e:
        logging.error(f"Diagnostics failed: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
