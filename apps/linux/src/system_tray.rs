//! System tray implementation using libappindicator

use crate::config_manager::ConfigManager;
use crate::server_manager::ServerManager;
use anyhow::{Context, Result};
use libappindicator::{AppIndicator, AppIndicatorStatus};
use std::path::PathBuf;
use std::sync::Arc;
use tracing::{error, info};

pub struct SystemTray {
    indicator: AppIndicator,
    config_manager: Arc<ConfigManager>,
    server_manager: Arc<ServerManager>,
}

impl SystemTray {
    pub fn new(
        config_manager: Arc<ConfigManager>,
        server_manager: Arc<ServerManager>,
    ) -> Result<Self> {
        // Create AppIndicator
        let mut indicator = AppIndicator::new("vibeproxy", "icon");
        indicator.set_status(AppIndicatorStatus::Active);

        Ok(Self {
            indicator,
            config_manager,
            server_manager,
        })
    }

    pub fn setup(&mut self) -> Result<()> {
        info!("Setting up system tray");

        // Set icon (fallback to default if not found)
        let icon_path = self.find_icon_path();
        if let Some(path) = icon_path {
            self.indicator.set_icon_full(&path, "VibeProxy");
        } else {
            // Use default icon name (system will find it)
            self.indicator.set_icon("application-default-icon");
        }

        // Create menu
        self.create_menu()?;

        info!("System tray setup complete");
        Ok(())
    }

    fn find_icon_path(&self) -> Option<PathBuf> {
        // Try common icon locations
        let possible_paths = vec![
            "/usr/share/pixmaps/vibeproxy.png",
            "/usr/share/icons/hicolor/48x48/apps/vibeproxy.png",
            "./resources/icon.png",
            "../resources/icon.png",
        ];

        for path in possible_paths {
            if std::path::Path::new(path).exists() {
                return Some(PathBuf::from(path));
            }
        }

        None
    }

    fn create_menu(&mut self) -> Result<()> {
        use gtk::prelude::*;
        use gtk::{glib, Menu, MenuItem};

        let menu = Menu::new();

        // Show Window
        let show_item = MenuItem::with_label("Show Window");
        let server_manager = self.server_manager.clone();
        show_item.connect_activate(move |_| {
            // TODO: Show main window
            info!("Show window requested");
        });
        menu.append(&show_item);

        // Separator
        menu.append(&gtk::SeparatorMenuItem::new());

        // Server status
        let status_item = MenuItem::with_label("Server: Stopped");
        menu.append(&status_item);

        // Start/Stop Server
        let toggle_item = MenuItem::with_label("Start Server");
        let server_manager_clone = self.server_manager.clone();
        let status_item_clone = status_item.clone();
        let toggle_item_clone = toggle_item.clone();
        toggle_item.connect_activate(move |_| {
            // Note: This requires a runtime handle - we'll need to pass it through
            // For now, this is a placeholder that will be fixed when integrating with app
            info!("Toggle server requested (requires runtime integration)");
        });
        menu.append(&toggle_item);

        // Separator
        menu.append(&gtk::SeparatorMenuItem::new());

        // Settings
        let settings_item = MenuItem::with_label("Settings");
        settings_item.connect_activate(|_| {
            // TODO: Open settings window
            info!("Settings requested");
        });
        menu.append(&settings_item);

        // Quit
        let quit_item = MenuItem::with_label("Quit");
        quit_item.connect_activate(|_| {
            info!("Quit requested");
            gtk::main_quit();
        });
        menu.append(&quit_item);

        menu.show_all();
        self.indicator.set_menu(&menu);

        Ok(())
    }
}
