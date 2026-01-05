#!/usr/bin/env python3
"""CLI script to run single assimilation cycle"""

import sys
import argparse
import logging
from datetime import datetime
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from wrf_dart.utils.config import load_config
from wrf_dart.core.job_scheduler import create_scheduler
from wrf_dart.core.cycle_manager import CycleManager


def setup_logging(level: str = "INFO") -> None:
    """Setup logging configuration"""
    logging.basicConfig(
        level=getattr(logging, level),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )


def main():
    """Main entry point for running single cycle"""
    parser = argparse.ArgumentParser(
        description="Run single WRF-DART assimilation cycle"
    )
    parser.add_argument(
        "--config",
        type=str,
        required=True,
        help="Path to experiment configuration file"
    )
    parser.add_argument(
        "--date",
        type=str,
        required=True,
        help="Cycle date in YYYYMMDDHH format"
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
    logger.info("WRF-DART Single Cycle Runner")
    logger.info("=" * 70)
    
    # Load configuration
    try:
        config = load_config(args.config)
    except Exception as e:
        logger.error(f"Failed to load configuration: {e}")
        return 1
    
    # Parse cycle date
    try:
        cycle_date = datetime.strptime(args.date, "%Y%m%d%H")
    except ValueError:
        logger.error(f"Invalid date format: {args.date}. Use YYYYMMDDHH")
        return 1
    
    # Create scheduler
    scheduler_type = config['batch']['scheduler']
    if args.dry_run:
        scheduler_type = "mock"
    
    scheduler = create_scheduler(scheduler_type, dry_run=args.dry_run)
    logger.info(f"Using scheduler: {scheduler_type}")
    
    # Create cycle manager
    cycle_mgr = CycleManager(config, scheduler, dry_run=args.dry_run)
    
    # Run cycle
    try:
        final_job_id = cycle_mgr.run_cycle(cycle_date)
        logger.info("=" * 70)
        logger.info(f"Cycle submitted successfully!")
        logger.info(f"Final job ID: {final_job_id}")
        logger.info("=" * 70)
        
        if args.dry_run:
            logger.info("DRY RUN - No actual jobs were submitted")
        
        return 0
    except Exception as e:
        logger.error(f"Cycle submission failed: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
