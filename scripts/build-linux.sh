#!/bin/bash
# Build script for VibeProxy Linux application

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Building VibeProxy Linux application..."

# Check for required tools
command -v cargo >/dev/null 2>&1 || { echo "Error: cargo is required but not installed. Aborting." >&2; exit 1; }
command -v pkg-config >/dev/null 2>&1 || { echo "Error: pkg-config is required but not installed. Aborting." >&2; exit 1; }

# Check for GTK4
if ! pkg-config --exists gtk4; then
    echo "Error: GTK4 development libraries not found."
    echo "Please install: libgtk-4-dev (Ubuntu/Debian) or gtk4-devel (Fedora)"
    exit 1
fi

# Check for libadwaita
if ! pkg-config --exists libadwaita-1; then
    echo "Error: libadwaita development libraries not found."
    echo "Please install: libadwaita-1-dev (Ubuntu/Debian) or libadwaita-devel (Fedora)"
    exit 1
fi

# Build shared core first
echo "Building shared core library..."
cd "$PROJECT_ROOT/shared/core"
cargo build --release --features linux

# Build Linux app
echo "Building Linux application..."
cd "$PROJECT_ROOT/apps/linux"
cargo build --release

echo "Build complete!"
echo "Binary location: $PROJECT_ROOT/apps/linux/target/release/vibeproxy"
