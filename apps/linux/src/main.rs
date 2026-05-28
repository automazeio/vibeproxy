//! VibeProxy Linux Application
//!
//! GTK4-based desktop application for managing Bifrost-enhanced AI routing.

mod app;
mod config_manager;
mod keyring;
mod server_manager;
mod system_tray;
mod ui;

use anyhow::Result;
use gtk::prelude::*;
use gtk::{gio, glib};
use tracing_subscriber;

fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "vibeproxy=info".into()),
        )
        .init();

    // Initialize GTK
    gtk::init()?;

    // Create application
    let app = app::VibeProxyApp::new();
    
    // Run application
    app.run();

    Ok(())
}
