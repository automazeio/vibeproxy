//! Server management (start/stop/status)

use crate::config_manager::ConfigManager;
use anyhow::{Context, Result};
use std::sync::Arc;
use tokio::runtime::Handle;
use tracing::{error, info, warn};
use vibeproxy_core::{BackendClient, ClientError};

pub struct ServerManager {
    config_manager: Arc<ConfigManager>,
    runtime: Handle,
    backend_client: Option<BackendClient>,
    is_running: Arc<std::sync::atomic::AtomicBool>,
}

impl ServerManager {
    pub fn new(config_manager: Arc<ConfigManager>, runtime: Handle) -> Result<Self> {
        Ok(Self {
            config_manager,
            runtime,
            backend_client: None,
            is_running: Arc::new(std::sync::atomic::AtomicBool::new(false)),
        })
    }

    pub async fn start(&self) -> Result<()> {
        if self.is_running.load(std::sync::atomic::Ordering::Relaxed) {
            warn!("Server is already running");
            return Ok(());
        }

        info!("Starting server");

        // Load configuration
        let config = self.config_manager.load()?;

        // Create backend client
        let client = BackendClient::new(&config.backend);

        // Check if server is already running
        match client.health_check().await {
            Ok(status) => {
                if status.healthy {
                    info!("Backend server is already running");
                    self.is_running.store(true, std::sync::atomic::Ordering::Relaxed);
                    return Ok(());
                }
            }
            Err(ClientError::Unavailable) => {
                info!("Backend server is not available, starting...");
                // TODO: Start the bifrost server process
                // For now, we just mark it as running if health check passes
                warn!("Server start not yet implemented - assuming server is external");
            }
            Err(e) => {
                error!("Failed to check server health: {}", e);
                return Err(e.into());
            }
        }

        self.is_running.store(true, std::sync::atomic::Ordering::Relaxed);
        info!("Server started successfully");

        Ok(())
    }

    pub async fn stop(&self) -> Result<()> {
        if !self.is_running.load(std::sync::atomic::Ordering::Relaxed) {
            warn!("Server is not running");
            return Ok(());
        }

        info!("Stopping server");

        // TODO: Stop the bifrost server process
        // For now, we just mark it as stopped
        warn!("Server stop not yet implemented - assuming server is external");

        self.is_running.store(false, std::sync::atomic::Ordering::Relaxed);
        info!("Server stopped successfully");

        Ok(())
    }

    pub async fn is_running(&self) -> bool {
        self.is_running.load(std::sync::atomic::Ordering::Relaxed)
    }

    pub async fn status(&self) -> Result<ServerStatus> {
        let config = self.config_manager.load()?;
        let client = BackendClient::new(&config.backend);

        match client.health_check().await {
            Ok(health) => Ok(ServerStatus {
                running: health.healthy,
                latency_ms: health.latency_ms,
                message: health.message,
            }),
            Err(ClientError::Unavailable) => Ok(ServerStatus {
                running: false,
                latency_ms: 0,
                message: Some("Server unavailable".to_string()),
            }),
            Err(e) => Err(e.into()),
        }
    }
}

#[derive(Debug, Clone)]
pub struct ServerStatus {
    pub running: bool,
    pub latency_ms: u64,
    pub message: Option<String>,
}
