"""Pytest configuration and fixtures"""

import pytest
from pathlib import Path
from datetime import datetime
import tempfile
import shutil


@pytest.fixture
def temp_dir():
    """Create temporary directory for test"""
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)


@pytest.fixture
def mock_config():
    """Mock configuration for testing"""
    return {
        'experiment': {
            'name': 'test_experiment',
            'start_date': '2017-04-27T06:00:00',
            'end_date': '2017-04-27T12:00:00',
        },
        'ensemble': {
            'size': 10,
        },
        'assimilation': {
            'window_hours': 6,
            'num_domains': 1,
            'adaptive_inflation': True,
            'increment_vars': ['U', 'V', 'T'],
        },
        'paths': {
            'base_dir': '/tmp/test',
            'output_dir': '/tmp/test/output',
            'run_dir': '/tmp/test/run',
            'dart_dir': '/opt/dart',
        },
        'batch': {
            'scheduler': 'mock',
            'account': 'TEST123',
            'email': 'test@test.com',
            'ic_prep': {
                'queue': 'main',
                'nodes': 1,
                'ntasks_per_node': 1,
                'walltime': '00:05:00',
                'memory': '5GB',
            },
            'filter': {
                'queue': 'main',
                'nodes': 2,
                'ntasks_per_node': 64,
                'walltime': '00:35:00',
                'memory': '235GB',
            },
            'advance': {
                'queue': 'main',
                'nodes': 1,
                'ntasks_per_node': 128,
                'walltime': '00:20:00',
                'memory': '235GB',
            },
            'diagnostics': {
                'queue': 'main',
                'nodes': 1,
                'ntasks_per_node': 1,
                'walltime': '00:10:00',
                'memory': '20GB',
            },
        },
        'dart': {
            'executables': {
                'filter': '/opt/dart/models/wrf/work/filter',
                'advance_time': '/opt/dart/models/wrf/work/advance_time',
            },
        },
        'wrf': {
            'namelist_template': '/opt/wrf/run/namelist.input',
            'executables': {
                'wrf': '/opt/wrf/run/wrf.exe',
            },
        },
        'logging': {
            'level': 'INFO',
        },
        'advanced': {
            'max_retries': 2,
        },
    }


@pytest.fixture
def cycle_date():
    """Standard cycle date for testing"""
    return datetime(2017, 4, 27, 6, 0, 0)


@pytest.fixture
def config_file(temp_dir, mock_config):
    """Create temporary config file"""
    import yaml
    config_path = temp_dir / "test_config.yaml"
    with open(config_path, 'w') as f:
        yaml.dump(mock_config, f)
    return str(config_path)
