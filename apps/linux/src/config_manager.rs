//! Configuration management

use anyhow::{Context, Result};
use directories::ProjectDirs;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use tracing::{error, info};
use vibeproxy_core::AppConfig;

pub struct ConfigManager {
    config_path: PathBuf,
}

impl ConfigManager {
    pub fn new() -> Self {
        let config_path = Self::get_config_path();
        Self { config_path }
    }

    fn get_config_path() -> PathBuf {
        if let Some(proj_dirs) = ProjectDirs::from("com", "vibeproxy", "VibeProxy") {
            let config_dir = proj_dirs.config_dir();
            std::fs::create_dir_all(config_dir)
                .expect("Failed to create config directory");
            config_dir.join("config.json")
        } else {
            // Fallback to current directory
            PathBuf::from("config.json")
        }
    }

    pub fn load(&self) -> Result<AppConfig> {
        info!("Loading configuration from: {:?}", self.config_path);

        if !self.config_path.exists() {
            info!("Config file not found, using defaults");
            return Ok(AppConfig::default());
        }

        let content = fs::read_to_string(&self.config_path)
            .context("Failed to read config file")?;

        let config: AppConfig = serde_json::from_str(&content)
            .context("Failed to parse config file")?;

        info!("Configuration loaded successfully");
        Ok(config)
    }

    pub fn save(&self, config: &AppConfig) -> Result<()> {
        info!("Saving configuration to: {:?}", self.config_path);

        let content = serde_json::to_string_pretty(config)
            .context("Failed to serialize config")?;

        fs::write(&self.config_path, content)
            .context("Failed to write config file")?;

        info!("Configuration saved successfully");
        Ok(())
    }

    pub fn get_config_path(&self) -> &PathBuf {
        &self.config_path
    }
}
