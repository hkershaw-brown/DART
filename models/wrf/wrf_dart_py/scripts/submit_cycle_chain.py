#!/usr/bin/env python3
"""CLI script to submit chain of dependent assimilation cycles"""

import sys
import argparse
import logging
from datetime import datetime
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from wrf_dart.utils.config import load_config
from wrf_dart.core.job_scheduler import create_scheduler
from wrf_dart.core.cycle_manager import MultiCycleManager


def setup_logging(level: str = "INFO") -> None:
    """Setup logging configuration"""
    logging.basicConfig(
        level=getattr(logging, level),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )


def main():
    """Main entry point for running cycle chain"""
    parser = argparse.ArgumentParser(
        description="Submit chain of WRF-DART assimilation cycles"
    )
    parser.add_argument(
        "--config",
        type=str,
        required=True,
        help="Path to experiment configuration file"
    )
    parser.add_argument(
        "--start-date",
        type=str,
        help="Start date (YYYYMMDDHH). Overrides config file."
    )
    parser.add_argument(
        "--end-date",
        type=str,
        help="End date (YYYYMMDDHH). Overrides config file."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate without actual job submission"
    )
    parser.add_argument(
        "--log-level",
        type=str,
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level"
    )
    
    args = parser.parse_args()
    
    # Setup logging
    setup_logging(args.log_level)
    logger = logging.getLogger(__name__)
    
    logger.info("=" * 70)
    logger.info("WRF-DART Multi-Cycle Chain Runner")
    logger.info("=" * 70)
    
    # Load configuration
    try:
        config = load_config(args.config)
    except Exception as e:
        logger.error(f"Failed to load configuration: {e}")
        return 1
    
    # Parse dates (from args or config)
    try:
        if args.start_date:
            start_date = datetime.strptime(args.start_date, "%Y%m%d%H")
        else:
            start_date = datetime.fromisoformat(config['experiment']['start_date'])
        
        if args.end_date:
            end_date = datetime.strptime(args.end_date, "%Y%m%d%H")
        else:
            end_date = datetime.fromisoformat(config['experiment']['end_date'])
    except (ValueError, KeyError) as e:
        logger.error(f"Invalid date: {e}")
        return 1
    
    # Validate date range
    if start_date >= end_date:
        logger.error("Start date must be before end date")
        return 1
    
    window_hours = config['assimilation']['window_hours']
    num_cycles = int((end_date - start_date).total_seconds() / 3600 / window_hours) + 1
    
    logger.info(f"Experiment: {config['experiment']['name']}")
    logger.info(f"Start date: {start_date:%Y-%m-%d %H:%M}")
    logger.info(f"End date:   {end_date:%Y-%m-%d %H:%M}")
    logger.info(f"Window:     {window_hours} hours")
    logger.info(f"Cycles:     {num_cycles}")
    logger.info(f"Ensemble:   {config['ensemble']['size']} members")
    
    # Create scheduler
    scheduler_type = config['batch']['scheduler']
    if args.dry_run:
        scheduler_type = "mock"
    
    scheduler = create_scheduler(scheduler_type, dry_run=args.dry_run)
    logger.info(f"Using scheduler: {scheduler_type}")
    
    # Create multi-cycle manager
    multi_mgr = MultiCycleManager(config, scheduler, dry_run=args.dry_run)
    
    # Run cycles
    try:
        multi_mgr.run_cycles(start_date, end_date)
        logger.info("=" * 70)
        logger.info(f"All {num_cycles} cycles submitted successfully!")
        logger.info("=" * 70)
        
        if args.dry_run:
            logger.info("DRY RUN - No actual jobs were submitted")
        
        return 0
    except Exception as e:
        logger.error(f"Cycle chain submission failed: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
