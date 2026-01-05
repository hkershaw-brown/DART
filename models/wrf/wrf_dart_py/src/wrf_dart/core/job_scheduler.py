"""Job scheduler abstraction for batch submission systems"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional, List
import subprocess
import re
import logging


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
    memory: Optional[str] = None
    dependency: Optional[str] = None
    array: Optional[str] = None
    priority: Optional[str] = None
    email: Optional[str] = None
    

class JobScheduler(ABC):
    """Abstract interface for batch schedulers"""
    
    def __init__(self, dry_run: bool = False):
        self.dry_run = dry_run
        self.logger = logging.getLogger(__name__)
    
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
    
    @abstractmethod
    def job_status(self, job_id: str) -> str:
        """Get job status"""
        pass


class SlurmScheduler(JobScheduler):
    """Slurm workload manager implementation"""
    
    def submit_job(self, config: JobConfig) -> str:
        """Submit job to Slurm"""
        cmd = ["sbatch"]
        cmd.extend(["--job-name", config.name])
        cmd.extend(["--partition", config.queue])
        cmd.extend(["--nodes", str(config.nodes)])
        cmd.extend(["--ntasks-per-node", str(config.ntasks)])
        cmd.extend(["--time", config.walltime])
        cmd.extend(["--account", config.account])
        
        if config.memory:
            cmd.extend(["--mem", config.memory])
        
        if config.dependency:
            cmd.extend(["--dependency", config.dependency])
        
        if config.array:
            cmd.extend(["--array", config.array])
        
        if config.priority:
            cmd.extend(["--qos", config.priority])
        
        if config.email:
            cmd.extend(["--mail-type", "END,FAIL"])
            cmd.extend(["--mail-user", config.email])
        
        cmd.extend(["--parsable"])
        cmd.append(config.script)
        
        if self.dry_run:
            self.logger.info(f"Would submit: {' '.join(cmd)}")
            return f"dry_run_{config.name}"
        
        self.logger.info(f"Submitting job: {config.name}")
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        
        job_id = self._parse_job_id(result.stdout)
        self.logger.info(f"Submitted job {config.name} with ID: {job_id}")
        return job_id
    
    def submit_array(self, config: JobConfig, array_size: int) -> str:
        """Submit job array to Slurm"""
        config.array = f"1-{array_size}"
        return self.submit_job(config)
    
    def cancel_job(self, job_id: str) -> None:
        """Cancel Slurm job"""
        if self.dry_run:
            self.logger.info(f"Would cancel job: {job_id}")
            return
        
        subprocess.run(["scancel", job_id], check=True)
        self.logger.info(f"Cancelled job: {job_id}")
    
    def job_status(self, job_id: str) -> str:
        """Get Slurm job status"""
        if self.dry_run:
            return "DRY_RUN"
        
        result = subprocess.run(
            ["squeue", "--job", job_id, "--noheader", "--format=%T"],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            return "NOT_FOUND"
        
        return result.stdout.strip()
    
    def _parse_job_id(self, output: str) -> str:
        """Parse job ID from sbatch output"""
        # Parsable format returns just the job ID
        return output.strip().split(";")[0]


class MockScheduler(JobScheduler):
    """Mock scheduler for testing without HPC"""
    
    def __init__(self, dry_run: bool = False):
        super().__init__(dry_run)
        self.submitted_jobs: List[dict] = []
        self.job_counter = 0
    
    def submit_job(self, config: JobConfig) -> str:
        """Mock job submission"""
        self.job_counter += 1
        job_id = f"mock_{self.job_counter}"
        
        self.submitted_jobs.append({
            'id': job_id,
            'config': config,
            'status': 'PENDING'
        })
        
        self.logger.info(f"Mock submitted: {config.name} -> {job_id}")
        return job_id
    
    def submit_array(self, config: JobConfig, array_size: int) -> str:
        """Mock array submission"""
        config.array = f"1-{array_size}"
        return self.submit_job(config)
    
    def cancel_job(self, job_id: str) -> None:
        """Mock job cancellation"""
        for job in self.submitted_jobs:
            if job['id'] == job_id:
                job['status'] = 'CANCELLED'
        self.logger.info(f"Mock cancelled: {job_id}")
    
    def job_status(self, job_id: str) -> str:
        """Mock job status"""
        for job in self.submitted_jobs:
            if job['id'] == job_id:
                return job['status']
        return "NOT_FOUND"
    
    def complete_job(self, job_id: str) -> None:
        """Helper for testing - mark job as completed"""
        for job in self.submitted_jobs:
            if job['id'] == job_id:
                job['status'] = 'COMPLETED'


def create_scheduler(scheduler_type: str, dry_run: bool = False) -> JobScheduler:
    """Factory function to create appropriate scheduler"""
    schedulers = {
        'slurm': SlurmScheduler,
        'mock': MockScheduler,
    }
    
    if scheduler_type not in schedulers:
        raise ValueError(f"Unknown scheduler type: {scheduler_type}")
    
    return schedulers[scheduler_type](dry_run=dry_run)


def build_dependency_string(job_ids: List[str], dep_type: str = "afterok") -> str:
    """Build Slurm dependency string
    
    Args:
        job_ids: List of job IDs
        dep_type: Dependency type (afterok, afterany, etc.)
    
    Returns:
        Dependency string like "afterok:123:124:125"
    """
    return f"{dep_type}:{':'.join(job_ids)}"
