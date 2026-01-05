"""Unit tests for job scheduler"""

import pytest
from wrf_dart.core.job_scheduler import (
    JobConfig,
    SlurmScheduler,
    MockScheduler,
    create_scheduler,
    build_dependency_string
)


class TestJobConfig:
    """Test JobConfig dataclass"""
    
    def test_job_config_creation(self):
        """Test creating JobConfig"""
        config = JobConfig(
            name="test_job",
            script="/path/to/script.py",
            queue="main",
            nodes=2,
            ntasks=128,
            walltime="01:00:00",
            account="TEST123"
        )
        
        assert config.name == "test_job"
        assert config.nodes == 2
        assert config.dependency is None


class TestMockScheduler:
    """Test MockScheduler"""
    
    def test_submit_job(self):
        """Test job submission"""
        scheduler = MockScheduler()
        
        config = JobConfig(
            name="test_job",
            script="test.py",
            queue="main",
            nodes=1,
            ntasks=1,
            walltime="00:10:00",
            account="TEST"
        )
        
        job_id = scheduler.submit_job(config)
        
        assert job_id == "mock_1"
        assert len(scheduler.submitted_jobs) == 1
        assert scheduler.submitted_jobs[0]['id'] == "mock_1"
        assert scheduler.submitted_jobs[0]['status'] == 'PENDING'
    
    def test_submit_array(self):
        """Test job array submission"""
        scheduler = MockScheduler()
        
        config = JobConfig(
            name="test_array",
            script="test.py",
            queue="main",
            nodes=1,
            ntasks=1,
            walltime="00:10:00",
            account="TEST"
        )
        
        job_id = scheduler.submit_array(config, array_size=50)
        
        assert job_id == "mock_1"
        assert scheduler.submitted_jobs[0]['config'].array == "1-50"
    
    def test_job_status(self):
        """Test job status query"""
        scheduler = MockScheduler()
        
        config = JobConfig(
            name="test",
            script="test.py",
            queue="main",
            nodes=1,
            ntasks=1,
            walltime="00:10:00",
            account="TEST"
        )
        
        job_id = scheduler.submit_job(config)
        
        assert scheduler.job_status(job_id) == "PENDING"
        
        scheduler.complete_job(job_id)
        assert scheduler.job_status(job_id) == "COMPLETED"
    
    def test_cancel_job(self):
        """Test job cancellation"""
        scheduler = MockScheduler()
        
        config = JobConfig(
            name="test",
            script="test.py",
            queue="main",
            nodes=1,
            ntasks=1,
            walltime="00:10:00",
            account="TEST"
        )
        
        job_id = scheduler.submit_job(config)
        scheduler.cancel_job(job_id)
        
        assert scheduler.job_status(job_id) == "CANCELLED"


class TestSlurmScheduler:
    """Test SlurmScheduler"""
    
    def test_parse_job_id(self):
        """Test parsing Slurm job ID"""
        scheduler = SlurmScheduler(dry_run=True)
        
        # Parsable format
        output = "12345678\n"
        job_id = scheduler._parse_job_id(output)
        assert job_id == "12345678"
        
        # With cluster suffix
        output = "12345678;cluster\n"
        job_id = scheduler._parse_job_id(output)
        assert job_id == "12345678"
    
    def test_dry_run_submission(self):
        """Test dry run mode"""
        scheduler = SlurmScheduler(dry_run=True)
        
        config = JobConfig(
            name="test",
            script="test.py",
            queue="main",
            nodes=1,
            ntasks=1,
            walltime="00:10:00",
            account="TEST"
        )
        
        job_id = scheduler.submit_job(config)
        assert job_id == "dry_run_test"


class TestHelperFunctions:
    """Test helper functions"""
    
    def test_build_dependency_string(self):
        """Test building dependency string"""
        jobs = ["123", "124", "125"]
        dep_str = build_dependency_string(jobs, "afterok")
        assert dep_str == "afterok:123:124:125"
        
        # Single job
        dep_str = build_dependency_string(["123"], "afterany")
        assert dep_str == "afterany:123"
    
    def test_create_scheduler(self):
        """Test scheduler factory"""
        scheduler = create_scheduler("mock")
        assert isinstance(scheduler, MockScheduler)
        
        scheduler = create_scheduler("slurm", dry_run=True)
        assert isinstance(scheduler, SlurmScheduler)
        
        with pytest.raises(ValueError):
            create_scheduler("invalid")
