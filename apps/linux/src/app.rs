//! Main application structure

use crate::config_manager::ConfigManager;
use crate::server_manager::ServerManager;
use crate::system_tray::SystemTray;
use crate::ui::MainWindow;
use anyhow::Result;
use gtk::prelude::*;
use gtk::{gio, glib, Application};
use std::sync::Arc;
use tokio::runtime::Runtime;
use tracing::{error, info};

pub struct VibeProxyApp {
    app: Application,
    runtime: Runtime,
    config_manager: Arc<ConfigManager>,
    server_manager: Arc<ServerManager>,
    system_tray: Option<SystemTray>,
    main_window: Option<MainWindow>,
}

impl VibeProxyApp {
    pub fn new() -> Self {
        // Create GTK application
        let app = Application::builder()
            .application_id("com.vibeproxy.app")
            .flags(gio::ApplicationFlags::NON_UNIQUE)
            .build();

        // Create async runtime
        let runtime = Runtime::new().expect("Failed to create Tokio runtime");

        // Initialize managers
        let config_manager = Arc::new(ConfigManager::new());
        let server_manager = Arc::new(
            ServerManager::new(config_manager.clone(), runtime.handle().clone())
                .expect("Failed to create server manager"),
        );

        Self {
            app,
            runtime,
            config_manager,
            server_manager,
            system_tray: None,
            main_window: None,
        }
    }

    pub fn run(&self) {
        // Connect activate signal
        let config_manager = self.config_manager.clone();
        let server_manager = self.server_manager.clone();
        let runtime_handle = self.runtime.handle().clone();

        self.app.connect_activate(move |app| {
            if let Err(e) = Self::on_activate(app, &config_manager, &server_manager, &runtime_handle)
            {
                error!("Failed to activate application: {}", e);
            }
        });

        // Run application
        self.app.run();
    }

    fn on_activate(
        app: &Application,
        config_manager: &Arc<ConfigManager>,
        server_manager: &Arc<ServerManager>,
        runtime: &tokio::runtime::Handle,
    ) -> Result<()> {
        info!("Activating VibeProxy application");

        // Load configuration
        let config = config_manager.load()?;
        info!("Configuration loaded");

        // Create system tray (runs in background)
        let system_tray = SystemTray::new(config_manager.clone(), server_manager.clone())?;
        system_tray.setup()?;

        // Create main window
        let window = MainWindow::new(app, config_manager.clone(), server_manager.clone(), runtime);
        window.present();

        info!("VibeProxy application activated");

        Ok(())
    }
}
