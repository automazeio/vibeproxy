#!/bin/bash
# Build all VibeProxy platforms

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔨 Building VibeProxy for all platforms..."

# Build shared Rust core
echo "📦 Building shared Rust core..."
cd "$ROOT_DIR/shared/core"
cargo build --release

# Build macOS app
echo "🍎 Building macOS app..."
cd "$ROOT_DIR/apps/macos"
swift build -c release

# Copy Rust library to macOS app bundle
echo "📋 Copying Rust library to macOS app..."
# This would be done during app bundle creation

echo "✅ Build complete!"
