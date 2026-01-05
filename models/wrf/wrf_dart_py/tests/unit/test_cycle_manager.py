"""Unit tests for cycle manager"""

import pytest
from datetime import datetime, timedelta
from wrf_dart.core.cycle_manager import CycleManager, MultiCycleManager
from wrf_dart.core.job_scheduler import MockScheduler


class TestCycleManager:
    """Test CycleManager class"""
    
    def test_initialization(self, mock_config):
        """Test cycle manager initialization"""
        scheduler = MockScheduler()
        manager = CycleManager(mock_config, scheduler)
        
        assert manager.ens_size == 10
        assert manager.account == "TEST123"
    
    def test_run_cycle_job_submission(self, mock_config, cycle_date):
        """Test that run_cycle submits correct jobs"""
        scheduler = MockScheduler()
        manager = CycleManager(mock_config, scheduler, dry_run=True)
        
        # Mock file existence check
        manager._verify_inputs = lambda x: None
        
        final_job_id = manager.run_cycle(cycle_date)
        
        # Should submit 4 jobs: prep_ic, filter, advance, diagnostics
        assert len(scheduler.submitted_jobs) == 4
        
        # Check job names and types
        job_names = [job['config'].name for job in scheduler.submitted_jobs]
        assert any('prep_ic' in name for name in job_names)
        assert any('filter' in name for name in job_names)
        assert any('advance' in name for name in job_names)
        assert any('diag' in name for name in job_names)
    
    def test_job_dependencies(self, mock_config, cycle_date):
        """Test that job dependencies are set correctly"""
        scheduler = MockScheduler()
        manager = CycleManager(mock_config, scheduler, dry_run=True)
        
        manager._verify_inputs = lambda x: None
        
        manager.run_cycle(cycle_date)
        
        # Get job IDs
        prep_id = scheduler.submitted_jobs[0]['id']
        filter_job = scheduler.submitted_jobs[1]
        advance_job = scheduler.submitted_jobs[2]
        diag_job = scheduler.submitted_jobs[3]
        
        # Filter should depend on prep
        assert filter_job['config'].dependency is not None
        assert prep_id in filter_job['config'].dependency
        
        # Advance should depend on filter
        assert advance_job['config'].dependency is not None
        assert filter_job['id'] in advance_job['config'].dependency
        
        # Diagnostics should depend on filter
        assert diag_job['config'].dependency is not None
        assert filter_job['id'] in diag_job['config'].dependency
    
    def test_job_array_size(self, mock_config, cycle_date):
        """Test that job arrays have correct size"""
        scheduler = MockScheduler()
        manager = CycleManager(mock_config, scheduler, dry_run=True)
        
        manager._verify_inputs = lambda x: None
        
        manager.run_cycle(cycle_date)
        
        # prep_ic and advance should be arrays of size ens_size
        prep_job = scheduler.submitted_jobs[0]
        advance_job = scheduler.submitted_jobs[2]
        
        assert prep_job['config'].array == "1-10"
        assert advance_job['config'].array == "1-10"


class TestMultiCycleManager:
    """Test MultiCycleManager class"""
    
    def test_initialization(self, mock_config):
        """Test multi-cycle manager initialization"""
        scheduler = MockScheduler()
        manager = MultiCycleManager(mock_config, scheduler)
        
        assert manager.config == mock_config
        assert manager.scheduler == scheduler
    
    def test_run_cycles(self, mock_config):
        """Test running multiple cycles"""
        scheduler = MockScheduler()
        manager = MultiCycleManager(mock_config, scheduler, dry_run=True)
        
        # Mock verify_inputs
        manager.cycle_mgr._verify_inputs = lambda x: None
        
        start_date = datetime(2017, 4, 27, 6)
        end_date = datetime(2017, 4, 27, 12)
        
        manager.run_cycles(start_date, end_date)
        
        # Should submit 2 cycles (06Z and 12Z)
        # Each cycle has 4 jobs
        assert len(scheduler.submitted_jobs) == 8
    
    def test_cycle_count(self, mock_config):
        """Test correct number of cycles"""
        scheduler = MockScheduler()
        manager = MultiCycleManager(mock_config, scheduler, dry_run=True)
        
        manager.cycle_mgr._verify_inputs = lambda x: None
        
        # 24-hour period with 6-hour windows = 5 cycles
        start_date = datetime(2017, 4, 27, 0)
        end_date = datetime(2017, 4, 28, 0)
        
        manager.run_cycles(start_date, end_date)
        
        # 5 cycles * 4 jobs each = 20 total jobs
        assert len(scheduler.submitted_jobs) == 20
