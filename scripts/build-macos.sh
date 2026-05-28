#!/bin/bash
# Build macOS app with Rust core integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$ROOT_DIR/shared/core"
MACOS_DIR="$ROOT_DIR/apps/macos"

echo "🍎 Building VibeProxy macOS app..."

# Step 1: Build shared Rust core
echo "📦 Step 1: Building shared Rust core..."
cd "$CORE_DIR"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="aarch64-apple-darwin"
else
    TARGET="x86_64-apple-darwin"
fi

cargo build --release --target "$TARGET"

# Step 2: Build macOS app
echo "🔨 Step 2: Building macOS app..."
cd "$MACOS_DIR"
swift build -c release

# Step 3: Create app bundle
echo "📦 Step 3: Creating app bundle..."
BUILD_DIR="$MACOS_DIR/.build/release"
BUNDLE_DIR="$BUILD_DIR/VibeProxy.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_BIN_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_BIN_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

# Copy executable
cp "$BUILD_DIR/CLIProxyMenuBar" "$MACOS_BIN_DIR/VibeProxy"

# Copy Rust library
RUST_LIB="$CORE_DIR/target/$TARGET/release/libvibeproxy_core.dylib"
if [ -f "$RUST_LIB" ]; then
    cp "$RUST_LIB" "$FRAMEWORKS_DIR/"
    # Update library path in executable
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_BIN_DIR/VibeProxy" 2>/dev/null || true
    echo "  ✓ Rust library bundled"
fi

# Copy resources
if [ -d "$MACOS_DIR/Sources/Resources" ]; then
    cp -r "$MACOS_DIR/Sources/Resources/"* "$RESOURCES_DIR/" 2>/dev/null || true
    echo "  ✓ Resources copied"
fi

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VibeProxy</string>
    <key>CFBundleIdentifier</key>
    <string>io.automaze.vibeproxy</string>
    <key>CFBundleName</key>
    <string>VibeProxy</string>
    <key>CFBundleDisplayName</key>
    <string>VibeProxy</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ macOS build complete!"
echo "   App bundle: $BUNDLE_DIR"
