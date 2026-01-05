"""Integration tests for complete workflow"""

import pytest
from datetime import datetime
from wrf_dart.core.cycle_manager import CycleManager
from wrf_dart.core.job_scheduler import MockScheduler


class TestWorkflowIntegration:
    """Integration tests for complete workflow"""
    
    def test_single_cycle_workflow(self, mock_config):
        """Test complete single cycle workflow"""
        scheduler = MockScheduler()
        manager = CycleManager(mock_config, scheduler, dry_run=True)
        
        # Mock file existence
        manager._verify_inputs = lambda x: None
        
        cycle_date = datetime(2017, 4, 27, 6)
        final_job_id = manager.run_cycle(cycle_date)
        
        # Verify workflow
        assert len(scheduler.submitted_jobs) == 4
        
        # Verify job sequence
        jobs = scheduler.submitted_jobs
        
        # Job 0: prep_ic array
        assert 'prep_ic' in jobs[0]['config'].name
        assert jobs[0]['config'].array == "1-10"
        assert jobs[0]['config'].dependency is None
        
        # Job 1: filter (depends on prep)
        assert 'filter' in jobs[1]['config'].name
        assert jobs[1]['config'].array is None
        assert jobs[0]['id'] in jobs[1]['config'].dependency
        
        # Job 2: advance array (depends on filter)
        assert 'advance' in jobs[2]['config'].name
        assert jobs[2]['config'].array == "1-10"
        assert jobs[1]['id'] in jobs[2]['config'].dependency
        
        # Job 3: diagnostics (depends on filter)
        assert 'diag' in jobs[3]['config'].name
        assert jobs[1]['id'] in jobs[3]['config'].dependency
        
        # Final job should be advance
        assert final_job_id == jobs[2]['id']
    
    def test_job_resource_allocation(self, mock_config):
        """Test that jobs get correct resource allocations"""
        scheduler = MockScheduler()
        manager = CycleManager(mock_config, scheduler, dry_run=True)
        
        manager._verify_inputs = lambda x: None
        
        cycle_date = datetime(2017, 4, 27, 6)
        manager.run_cycle(cycle_date)
        
        jobs = scheduler.submitted_jobs
        
        # Check filter gets multi-node allocation
        filter_job = jobs[1]
        assert filter_job['config'].nodes == 2
        assert filter_job['config'].ntasks == 64
        assert filter_job['config'].walltime == "00:35:00"
        
        # Check advance gets correct resources
        advance_job = jobs[2]
        assert advance_job['config'].nodes == 1
        assert advance_job['config'].ntasks == 128
    
    def test_job_submission_order(self, mock_config):
        """Test jobs are submitted in correct order"""
        scheduler = MockScheduler()
        manager = CycleManager(mock_config, scheduler, dry_run=True)
        
        manager._verify_inputs = lambda x: None
        
        cycle_date = datetime(2017, 4, 27, 6)
        manager.run_cycle(cycle_date)
        
        # Extract job submission order
        job_types = []
        for job in scheduler.submitted_jobs:
            name = job['config'].name
            if 'prep_ic' in name:
                job_types.append('prep')
            elif 'filter' in name:
                job_types.append('filter')
            elif 'advance' in name:
                job_types.append('advance')
            elif 'diag' in name:
                job_types.append('diag')
        
        # Should be: prep, filter, advance, diag
        assert job_types == ['prep', 'filter', 'advance', 'diag']
    
    def test_dry_run_no_side_effects(self, mock_config):
        """Test dry run doesn't create files or submit real jobs"""
        scheduler = MockScheduler()
        manager = CycleManager(mock_config, scheduler, dry_run=True)
        
        manager._verify_inputs = lambda x: None
        
        cycle_date = datetime(2017, 4, 27, 6)
        final_job_id = manager.run_cycle(cycle_date)
        
        # All job IDs should be mock
        for job in scheduler.submitted_jobs:
            assert job['id'].startswith('mock_')
        
        assert final_job_id.startswith('mock_')


class TestMultiCycleIntegration:
    """Integration tests for multi-cycle workflows"""
    
    def test_two_cycle_chain(self, mock_config):
        """Test two consecutive cycles"""
        from wrf_dart.core.cycle_manager import MultiCycleManager
        
        scheduler = MockScheduler()
        manager = MultiCycleManager(mock_config, scheduler, dry_run=True)
        
        manager.cycle_mgr._verify_inputs = lambda x: None
        
        start_date = datetime(2017, 4, 27, 6)
        end_date = datetime(2017, 4, 27, 12)
        
        manager.run_cycles(start_date, end_date)
        
        # 2 cycles * 4 jobs = 8 total
        assert len(scheduler.submitted_jobs) == 8
        
        # Verify both cycles present
        dates_in_jobs = set()
        for job in scheduler.submitted_jobs:
            name = job['config'].name
            # Extract date from job name (format: job_name_YYYYMMDDHH)
            if '2017042706' in name:
                dates_in_jobs.add('2017042706')
            if '2017042712' in name:
                dates_in_jobs.add('2017042712')
        
        assert len(dates_in_jobs) == 2
