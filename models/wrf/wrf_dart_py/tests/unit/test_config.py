"""Unit tests for configuration utilities"""

import pytest
import yaml
from pathlib import Path
from wrf_dart.utils.config import (
    load_config,
    deep_merge,
    expand_env_vars,
    validate_config,
    save_config
)


class TestDeepMerge:
    """Test deep_merge function"""
    
    def test_simple_merge(self):
        """Test merging simple dictionaries"""
        base = {'a': 1, 'b': 2}
        override = {'b': 3, 'c': 4}
        
        result = deep_merge(base, override)
        
        assert result == {'a': 1, 'b': 3, 'c': 4}
    
    def test_nested_merge(self):
        """Test merging nested dictionaries"""
        base = {
            'level1': {
                'level2': {
                    'a': 1,
                    'b': 2
                }
            }
        }
        override = {
            'level1': {
                'level2': {
                    'b': 3,
                    'c': 4
                }
            }
        }
        
        result = deep_merge(base, override)
        
        assert result['level1']['level2'] == {'a': 1, 'b': 3, 'c': 4}


class TestExpandEnvVars:
    """Test expand_env_vars function"""
    
    def test_expand_env_var(self, monkeypatch):
        """Test environment variable expansion"""
        monkeypatch.setenv('USER', 'testuser')
        
        config = {
            'paths': {
                'base': '/home/${USER}/work'
            }
        }
        
        result = expand_env_vars(config)
        
        assert result['paths']['base'] == '/home/testuser/work'
    
    def test_nested_expansion(self, monkeypatch):
        """Test nested variable expansion"""
        monkeypatch.setenv('USER', 'testuser')
        monkeypatch.setenv('PROJECT', 'dart')
        
        config = {
            'paths': {
                'level1': {
                    'level2': '/home/${USER}/${PROJECT}'
                }
            }
        }
        
        result = expand_env_vars(config)
        
        assert result['paths']['level1']['level2'] == '/home/testuser/dart'


class TestValidateConfig:
    """Test validate_config function"""
    
    def test_valid_config(self, mock_config):
        """Test validation of valid config"""
        # Should not raise exception
        validate_config(mock_config)
    
    def test_missing_section(self, mock_config):
        """Test validation fails with missing section"""
        del mock_config['ensemble']
        
        with pytest.raises(ValueError, match="Missing required configuration section"):
            validate_config(mock_config)
    
    def test_missing_field(self, mock_config):
        """Test validation fails with missing field"""
        del mock_config['experiment']['name']
        
        with pytest.raises(ValueError, match="Missing required experiment field"):
            validate_config(mock_config)
    
    def test_invalid_ensemble_size(self, mock_config):
        """Test validation fails with invalid ensemble size"""
        mock_config['ensemble']['size'] = 0
        
        with pytest.raises(ValueError, match="Ensemble size must be"):
            validate_config(mock_config)
    
    def test_invalid_scheduler(self, mock_config):
        """Test validation fails with invalid scheduler"""
        mock_config['batch']['scheduler'] = 'invalid'
        
        with pytest.raises(ValueError, match="Invalid scheduler"):
            validate_config(mock_config)
    
    def test_missing_account(self, mock_config):
        """Test validation fails without batch account"""
        del mock_config['batch']['account']
        
        with pytest.raises(ValueError, match="Batch account must be specified"):
            validate_config(mock_config)


class TestLoadConfig:
    """Test load_config function"""
    
    def test_load_config_success(self, config_file):
        """Test successful config loading"""
        config = load_config(config_file)
        
        assert config['experiment']['name'] == 'test_experiment'
        assert config['ensemble']['size'] == 10
    
    def test_load_nonexistent_file(self):
        """Test loading non-existent file"""
        with pytest.raises(FileNotFoundError):
            load_config('/nonexistent/config.yaml')


class TestSaveConfig:
    """Test save_config function"""
    
    def test_save_config(self, temp_dir, mock_config):
        """Test saving configuration"""
        output_path = temp_dir / "saved_config.yaml"
        
        save_config(mock_config, str(output_path))
        
        assert output_path.exists()
        
        # Load and verify
        with open(output_path) as f:
            loaded = yaml.safe_load(f)
        
        assert loaded['experiment']['name'] == mock_config['experiment']['name']
