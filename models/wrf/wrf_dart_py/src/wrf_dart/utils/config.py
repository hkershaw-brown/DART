"""Configuration loading and validation"""

import os
import yaml
from pathlib import Path
from typing import Dict, Any
import logging


def load_config(config_path: str) -> Dict[str, Any]:
    """Load and merge configuration files
    
    Args:
        config_path: Path to user configuration file
        
    Returns:
        Merged configuration dictionary
    """
    logger = logging.getLogger(__name__)
    
    # Load defaults
    defaults_path = Path(__file__).parent.parent.parent.parent / "config" / "defaults.yaml"
    with open(defaults_path) as f:
        config = yaml.safe_load(f)
    
    # Load user config and merge
    user_config_path = Path(config_path)
    if not user_config_path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    with open(user_config_path) as f:
        user_config = yaml.safe_load(f)
    
    config = deep_merge(config, user_config)
    
    # Expand environment variables in paths
    config = expand_env_vars(config)
    
    # Validate configuration
    validate_config(config)
    
    logger.info(f"Loaded configuration from {config_path}")
    return config


def deep_merge(base: Dict, override: Dict) -> Dict:
    """Deep merge two dictionaries
    
    Args:
        base: Base dictionary
        override: Override dictionary
        
    Returns:
        Merged dictionary
    """
    result = base.copy()
    
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    
    return result


def expand_env_vars(config: Dict) -> Dict:
    """Recursively expand environment variables in config values
    
    Args:
        config: Configuration dictionary
        
    Returns:
        Configuration with expanded environment variables
    """
    result = {}
    
    for key, value in config.items():
        if isinstance(value, dict):
            result[key] = expand_env_vars(value)
        elif isinstance(value, str):
            # Expand environment variables
            result[key] = os.path.expandvars(value)
        else:
            result[key] = value
    
    return result


def validate_config(config: Dict) -> None:
    """Validate configuration has required fields
    
    Args:
        config: Configuration dictionary
        
    Raises:
        ValueError: If required fields are missing or invalid
    """
    # Required top-level sections
    required_sections = ['experiment', 'ensemble', 'assimilation', 'paths', 'batch']
    for section in required_sections:
        if section not in config:
            raise ValueError(f"Missing required configuration section: {section}")
    
    # Required experiment fields
    exp_fields = ['name', 'start_date', 'end_date']
    for field in exp_fields:
        if field not in config['experiment']:
            raise ValueError(f"Missing required experiment field: {field}")
    
    # Validate ensemble size
    if config['ensemble']['size'] < 1:
        raise ValueError("Ensemble size must be >= 1")
    
    # Validate paths exist (for some critical ones)
    critical_paths = ['dart_dir']
    for path_key in critical_paths:
        if path_key in config['paths']:
            path = Path(config['paths'][path_key])
            if not path.exists():
                logging.warning(f"Path does not exist: {path_key} = {path}")
    
    # Validate scheduler type
    valid_schedulers = ['slurm', 'pbs', 'lsf', 'mock']
    if config['batch']['scheduler'] not in valid_schedulers:
        raise ValueError(
            f"Invalid scheduler: {config['batch']['scheduler']}. "
            f"Must be one of {valid_schedulers}"
        )
    
    # Validate batch account provided
    if not config['batch'].get('account'):
        raise ValueError("Batch account must be specified")


def save_config(config: Dict, output_path: str) -> None:
    """Save configuration to YAML file
    
    Args:
        config: Configuration dictionary
        output_path: Output file path
    """
    with open(output_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
