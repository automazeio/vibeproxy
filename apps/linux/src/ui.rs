//! Main window UI

use crate::config_manager::ConfigManager;
use crate::server_manager::ServerManager;
use adw::prelude::*;
use adw::{ApplicationWindow, HeaderBar};
use gtk::prelude::*;
use gtk::{Application, Box, Button, Label, Orientation, ScrolledWindow};
use std::sync::Arc;
use tokio::runtime::Handle;
use tracing::info;

pub struct MainWindow {
    window: ApplicationWindow,
    config_manager: Arc<ConfigManager>,
    server_manager: Arc<ServerManager>,
    runtime: Handle,
}

impl MainWindow {
    pub fn new(
        app: &Application,
        config_manager: Arc<ConfigManager>,
        server_manager: Arc<ServerManager>,
        runtime: &Handle,
    ) -> Self {
        info!("Creating main window");

        // Create application window
        let window = ApplicationWindow::builder()
            .application(app)
            .title("VibeProxy")
            .default_width(600)
            .default_height(500)
            .build();

        // Create header bar
        let header = HeaderBar::new();
        window.set_titlebar(Some(&header));

        // Create main content
        let content = Box::new(Orientation::Vertical, 12);
        content.set_margin_start(12);
        content.set_margin_end(12);
        content.set_margin_top(12);
        content.set_margin_bottom(12);

        // Server status section
        let status_label = Label::builder()
            .label("Server Status")
            .css_classes(&["title-2"])
            .build();
        content.append(&status_label);

        let server_status = Label::builder()
            .label("Stopped")
            .css_classes(&["body"])
            .build();
        content.append(&server_status);

        // Server control buttons
        let button_box = Box::new(Orientation::Horizontal, 6);

        let start_button = Button::with_label("Start Server");
        let stop_button = Button::with_label("Stop Server");
        stop_button.set_sensitive(false);

        let server_manager_clone = server_manager.clone();
        let server_status_clone = server_status.clone();
        let stop_button_clone = stop_button.clone();
        let start_button_clone = start_button.clone();

        start_button.connect_clicked({
            let runtime = runtime.clone();
            move |_| {
                runtime.block_on(async {
                    if let Err(e) = server_manager_clone.start().await {
                        eprintln!("Failed to start server: {}", e);
                    } else {
                        server_status_clone.set_label("Running");
                        start_button_clone.set_sensitive(false);
                        stop_button_clone.set_sensitive(true);
                    }
                });
            }
        });

        stop_button.connect_clicked({
            let runtime = runtime.clone();
            let server_manager_stop = server_manager.clone();
            let server_status_stop = server_status.clone();
            let start_button_stop = start_button.clone();
            let stop_button_stop = stop_button.clone();

            move |_| {
                runtime.block_on(async {
                    if let Err(e) = server_manager_stop.stop().await {
                        eprintln!("Failed to stop server: {}", e);
                    } else {
                        server_status_stop.set_label("Stopped");
                        start_button_stop.set_sensitive(true);
                        stop_button_stop.set_sensitive(false);
                    }
                });
            }
        });

        button_box.append(&start_button);
        button_box.append(&stop_button);
        content.append(&button_box);

        // Settings section
        let settings_label = Label::builder()
            .label("Settings")
            .css_classes(&["title-2"])
            .build();
        content.append(&settings_label);

        let settings_button = Button::with_label("Open Settings");
        settings_button.connect_clicked(|_| {
            info!("Settings button clicked");
            // TODO: Open settings window
        });
        content.append(&settings_button);

        // Add content to window
        let scrolled = ScrolledWindow::new();
        scrolled.set_child(Some(&content));
        window.set_content(Some(&scrolled));

        info!("Main window created");

        Self {
            window,
            config_manager,
            server_manager,
            runtime: runtime.clone(),
        }
    }

    pub fn present(&self) {
        self.window.present();
    }
}
