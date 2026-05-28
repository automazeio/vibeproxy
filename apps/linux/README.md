# VibeProxy Linux Application

GTK4-based desktop application for managing Bifrost-enhanced AI routing on Linux.

## Prerequisites

### Required Packages

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    pkg-config \
    libgtk-4-dev \
    libadwaita-1-dev \
    libappindicator3-dev \
    libsecret-1-dev \
    libssl-dev
```

**Fedora:**
```bash
sudo dnf install -y \
    gcc \
    pkg-config \
    gtk4-devel \
    libadwaita-devel \
    libappindicator-gtk3-devel \
    libsecret-devel \
    openssl-devel
```

**Arch Linux:**
```bash
sudo pacman -S --needed \
    base-devel \
    pkg-config \
    gtk4 \
    libadwaita \
    libappindicator-gtk3 \
    libsecret \
    openssl
```

### Rust Toolchain

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

## Building

### Build the Linux App

```bash
cd apps/linux
cargo build --release
```

### Build with Shared Core

The shared core library must be built first:

```bash
cd shared/core
cargo build --release --features linux
cd ../../apps/linux
cargo build --release
```

## Running

```bash
cargo run --release
```

Or run the built binary:

```bash
./target/release/vibeproxy
```

## Features

- ✅ GTK4 main window
- ✅ System tray integration (AppIndicator)
- ✅ Keyring integration (libsecret)
- ✅ Server control (start/stop/status)
- ✅ Configuration management
- 🚧 Settings UI (in progress)

## Architecture

```
apps/linux/
├── src/
│   ├── main.rs          # Application entry point
│   ├── app.rs           # Main application structure
│   ├── ui.rs            # Main window UI
│   ├── system_tray.rs   # System tray implementation
│   ├── keyring.rs       # Keyring integration
│   ├── config_manager.rs # Configuration management
│   └── server_manager.rs # Server control
└── Cargo.toml           # Rust dependencies
```

## Development

### Running in Development Mode

```bash
RUST_LOG=vibeproxy=debug cargo run
```

### Testing

```bash
cargo test
```

## Troubleshooting

### Missing GTK4 Libraries

If you get errors about missing GTK4 libraries, ensure you have installed the development packages:

```bash
pkg-config --modversion gtk4
```

### Keyring Issues

If keyring operations fail, ensure the secret service is running:

```bash
systemctl --user status gnome-keyring-daemon
```

### System Tray Not Showing

Some desktop environments require additional packages:
- **KDE**: Install `libappindicator` package
- **XFCE**: May need `xfce4-statusnotifier-plugin`

## License

MIT
