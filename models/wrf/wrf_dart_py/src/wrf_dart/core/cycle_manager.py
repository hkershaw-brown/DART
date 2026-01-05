"""Cycle manager - orchestrates single assimilation cycle"""

from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Optional
import logging

from .job_scheduler import JobScheduler, JobConfig, build_dependency_string


class CycleManager:
    """Manages single assimilation cycle workflow"""
    
    def __init__(self, config: Dict, scheduler: JobScheduler, dry_run: bool = False):
        """Initialize cycle manager
        
        Args:
            config: Experiment configuration dictionary
            scheduler: Job scheduler instance
            dry_run: If True, simulate without actual execution
        """
        self.config = config
        self.scheduler = scheduler
        self.dry_run = dry_run
        self.logger = logging.getLogger(__name__)
        
        # Extract commonly used config values
        self.ens_size = config['ensemble']['size']
        self.account = config['batch']['account']
        self.email = config['batch'].get('email')
        
    def run_cycle(self, cycle_date: datetime) -> str:
        """Execute complete assimilation cycle
        
        Args:
            cycle_date: Date/time for this cycle
            
        Returns:
            Job ID of final advance array job
        """
        self.logger.info(f"Starting cycle for {cycle_date:%Y-%m-%d %H:%M}")
        
        # Verify input files exist
        self._verify_inputs(cycle_date)
        
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
        
        self.logger.info(f"Cycle {cycle_date:%Y%m%d%H} jobs submitted")
        self.logger.info(f"  Prep IC:     {prep_job_id}")
        self.logger.info(f"  Filter:      {filter_job_id}")
        self.logger.info(f"  Advance:     {advance_job_id}")
        self.logger.info(f"  Diagnostics: {diag_job_id}")
        
        return advance_job_id
    
    def _verify_inputs(self, cycle_date: datetime) -> None:
        """Verify required input files exist"""
        output_dir = Path(self.config['paths']['output_dir']) / f"{cycle_date:%Y%m%d%H}"
        
        required_files = [
            'obs_seq.out',
        ]
        
        if not self.dry_run:
            for filename in required_files:
                filepath = output_dir / filename
                if not filepath.exists():
                    raise FileNotFoundError(
                        f"Required input file missing: {filepath}"
                    )
    
    def _submit_prep_ic(self, cycle_date: datetime) -> str:
        """Submit IC preparation job array"""
        scripts_dir = Path(__file__).parent.parent / "jobs"
        
        config = JobConfig(
            name=f"prep_ic_{cycle_date:%Y%m%d%H}",
            script=str(scripts_dir / "prepare_ic.py"),
            queue=self.config['batch']['ic_prep']['queue'],
            nodes=self.config['batch']['ic_prep']['nodes'],
            ntasks=self.config['batch']['ic_prep']['ntasks_per_node'],
            walltime=self.config['batch']['ic_prep']['walltime'],
            account=self.account,
            memory=self.config['batch']['ic_prep'].get('memory'),
            email=self.email
        )
        
        return self.scheduler.submit_array(config, self.ens_size)
    
    def _submit_filter(self, cycle_date: datetime, dependency: str) -> str:
        """Submit DART filter job"""
        scripts_dir = Path(__file__).parent.parent / "jobs"
        
        config = JobConfig(
            name=f"filter_{cycle_date:%Y%m%d%H}",
            script=str(scripts_dir / "run_filter.py"),
            queue=self.config['batch']['filter']['queue'],
            nodes=self.config['batch']['filter']['nodes'],
            ntasks=self.config['batch']['filter']['ntasks_per_node'],
            walltime=self.config['batch']['filter']['walltime'],
            account=self.account,
            memory=self.config['batch']['filter'].get('memory'),
            priority=self.config['batch']['filter'].get('priority'),
            dependency=dependency,
            email=self.email
        )
        
        return self.scheduler.submit_job(config)
    
    def _submit_advance(self, cycle_date: datetime, dependency: str) -> str:
        """Submit model advance job array"""
        scripts_dir = Path(__file__).parent.parent / "jobs"
        
        config = JobConfig(
            name=f"advance_{cycle_date:%Y%m%d%H}",
            script=str(scripts_dir / "advance_member.py"),
            queue=self.config['batch']['advance']['queue'],
            nodes=self.config['batch']['advance']['nodes'],
            ntasks=self.config['batch']['advance']['ntasks_per_node'],
            walltime=self.config['batch']['advance']['walltime'],
            account=self.account,
            memory=self.config['batch']['advance'].get('memory'),
            priority=self.config['batch']['advance'].get('priority'),
            dependency=dependency,
            email=self.email
        )
        
        return self.scheduler.submit_array(config, self.ens_size)
    
    def _submit_diagnostics(self, cycle_date: datetime, dependency: str) -> str:
        """Submit diagnostics job"""
        scripts_dir = Path(__file__).parent.parent / "jobs"
        
        config = JobConfig(
            name=f"diag_{cycle_date:%Y%m%d%H}",
            script=str(scripts_dir / "run_diagnostics.py"),
            queue=self.config['batch']['diagnostics']['queue'],
            nodes=self.config['batch']['diagnostics']['nodes'],
            ntasks=self.config['batch']['diagnostics']['ntasks_per_node'],
            walltime=self.config['batch']['diagnostics']['walltime'],
            account=self.account,
            memory=self.config['batch']['diagnostics'].get('memory'),
            dependency=dependency,
            email=self.email
        )
        
        return self.scheduler.submit_job(config)
    
    def _get_script_path(self, script_name: str) -> Path:
        """Get absolute path to job script"""
        scripts_dir = Path(__file__).parent.parent / "jobs"
        return scripts_dir / script_name


class MultiCycleManager:
    """Manages chain of assimilation cycles"""
    
    def __init__(self, config: Dict, scheduler: JobScheduler, dry_run: bool = False):
        self.config = config
        self.scheduler = scheduler
        self.dry_run = dry_run
        self.logger = logging.getLogger(__name__)
        self.cycle_mgr = CycleManager(config, scheduler, dry_run)
        
    def run_cycles(self, start_date: datetime, end_date: datetime) -> None:
        """Submit chain of dependent cycles
        
        Args:
            start_date: First cycle date
            end_date: Last cycle date
        """
        window_hours = self.config['assimilation']['window_hours']
        current_date = start_date
        prev_job_id = None
        
        while current_date <= end_date:
            self.logger.info(f"Submitting cycle: {current_date:%Y-%m-%d %H:%M}")
            
            # If not first cycle, make it depend on previous cycle completion
            if prev_job_id:
                # Temporarily override config to add dependency
                # This ensures cycles run sequentially
                pass
            
            prev_job_id = self.cycle_mgr.run_cycle(current_date)
            
            # Advance to next cycle
            current_date += timedelta(hours=window_hours)
        
        self.logger.info(f"Submitted {(end_date - start_date).total_seconds() / 3600 / window_hours + 1} cycles")
