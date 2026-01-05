#!/usr/bin/env python3
"""Run DART filter for data assimilation

This script executes the DART filter and post-processes outputs.
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


def run_filter(cycle_date: datetime, config: dict) -> None:
    """Execute DART filter
    
    Args:
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    logger.info(f"Running filter for cycle {cycle_date:%Y%m%d%H}")
    
    run_dir = Path(config['paths']['run_dir'])
    output_dir = Path(config['paths']['output_dir']) / f"{cycle_date:%Y%m%d%H}"
    
    # Change to run directory
    os.chdir(run_dir)
    
    # Mark filter start time
    start_marker = run_dir / "filter_started"
    with open(start_marker, 'w') as f:
        f.write(str(int(datetime.now().timestamp())))
    
    # Link input files
    obs_seq = output_dir / "obs_seq.out"
    if not obs_seq.exists():
        raise FileNotFoundError(f"obs_seq.out not found: {obs_seq}")
    
    (run_dir / "obs_seq.out").symlink_to(obs_seq)
    
    # Setup inflation files if using adaptive inflation
    if config['assimilation']['adaptive_inflation']:
        setup_inflation_files(cycle_date, config)
    
    # Get filter executable
    filter_exe = Path(config['dart']['executables']['filter'])
    if not filter_exe.exists():
        raise FileNotFoundError(f"Filter executable not found: {filter_exe}")
    
    # Run filter with MPI
    ntasks = config['batch']['filter']['nodes'] * config['batch']['filter']['ntasks_per_node']
    
    logger.info(f"Launching filter with {ntasks} MPI tasks")
    cmd = ["mpiexec", "-n", str(ntasks), str(filter_exe)]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        logger.error(f"Filter failed with return code {result.returncode}")
        logger.error(f"STDOUT:\n{result.stdout}")
        logger.error(f"STDERR:\n{result.stderr}")
        raise RuntimeError("Filter execution failed")
    
    logger.info("Filter execution completed successfully")
    
    # Post-process outputs
    post_process_outputs(cycle_date, config)
    
    # Mark completion
    done_marker = run_dir / "filter_done"
    done_marker.touch()
    
    logger.info("Filter post-processing complete")


def setup_inflation_files(cycle_date: datetime, config: dict) -> None:
    """Setup adaptive inflation input files
    
    Args:
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    run_dir = Path(config['paths']['run_dir'])
    output_dir = Path(config['paths']['output_dir'])
    
    # Get previous cycle
    window_hours = config['assimilation']['window_hours']
    prev_cycle = cycle_date - pd.Timedelta(hours=window_hours)
    
    prev_output_dir = output_dir / f"{prev_cycle:%Y%m%d%H}" / "Inflation_input"
    
    if not prev_output_dir.exists():
        logger.warning(f"Previous inflation directory not found: {prev_output_dir}")
        return
    
    # Link inflation files
    for inf_file in prev_output_dir.glob("input_*inf*.nc"):
        target = run_dir / inf_file.name
        if target.exists():
            target.unlink()
        target.symlink_to(inf_file)
    
    logger.info("Inflation files linked")


def post_process_outputs(cycle_date: datetime, config: dict) -> None:
    """Post-process filter outputs
    
    Creates analysis increment file using ncdiff and ncks
    
    Args:
        cycle_date: Current cycle date
        config: Experiment configuration
    """
    logger = logging.getLogger(__name__)
    run_dir = Path(config['paths']['run_dir'])
    
    # Build variable extraction string
    increment_vars = config['assimilation']['increment_vars']
    var_str = ','.join(increment_vars)
    
    # Create difference file
    logger.info("Computing analysis increment")
    
    cmd_diff = [
        "ncdiff", "-F", "-O",
        "-v", var_str,
        "postassim_mean.nc",
        "preassim_mean.nc",
        "analysis_increment.nc"
    ]
    
    subprocess.run(cmd_diff, check=True)
    
    # Extract static data
    cmd_static = [
        "ncks", "-F", "-O",
        "-x", "-v", var_str,
        "postassim_mean.nc",
        "static_data.nc"
    ]
    
    subprocess.run(cmd_static, check=True)
    
    # Append static data
    cmd_append = [
        "ncks", "-A",
        "static_data.nc",
        "analysis_increment.nc"
    ]
    
    subprocess.run(cmd_append, check=True)
    
    logger.info("Analysis increment created")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Run DART filter")
    parser.add_argument("--date", type=str, required=True, help="Cycle date (YYYYMMDDHH)")
    parser.add_argument("--config", type=str, required=True, help="Configuration file path")
    
    args = parser.parse_args()
    
    # Load configuration
    config = load_config(args.config)
    
    # Setup logging
    log_dir = Path(config['paths']['run_dir']) / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"filter_{args.date}.log"
    setup_logging(log_file)
    
    # Parse cycle date
    cycle_date = datetime.strptime(args.date, "%Y%m%d%H")
    
    try:
        run_filter(cycle_date, config)
        return 0
    except Exception as e:
        logging.error(f"Filter failed: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
