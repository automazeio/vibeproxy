#!/bin/bash
# Build the Rust core library for all platforms

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/../shared/core"
BINDINGS_DIR="$SCRIPT_DIR/../shared/bindings"

echo "=== Building VibeProxy Core Library ==="

cd "$CORE_DIR"

# Detect current platform
case "$(uname -s)" in
    Darwin)
        echo "Building for macOS..."
        
        # Build for x86_64
        echo "  -> x86_64-apple-darwin"
        cargo build --release --target x86_64-apple-darwin 2>/dev/null || \
            cargo build --release
        
        # Build for aarch64 (Apple Silicon)
        echo "  -> aarch64-apple-darwin"
        cargo build --release --target aarch64-apple-darwin 2>/dev/null || true
        
        # Create universal binary if both exist
        if [ -f "target/x86_64-apple-darwin/release/libvibeproxy_core.dylib" ] && \
           [ -f "target/aarch64-apple-darwin/release/libvibeproxy_core.dylib" ]; then
            echo "Creating universal binary..."
            mkdir -p target/universal/release
            lipo -create \
                target/x86_64-apple-darwin/release/libvibeproxy_core.dylib \
                target/aarch64-apple-darwin/release/libvibeproxy_core.dylib \
                -output target/universal/release/libvibeproxy_core.dylib
        fi
        
        # Copy to bindings
        mkdir -p "$BINDINGS_DIR/swift"
        if [ -f "target/universal/release/libvibeproxy_core.dylib" ]; then
            cp target/universal/release/libvibeproxy_core.dylib "$BINDINGS_DIR/swift/"
        elif [ -f "target/release/libvibeproxy_core.dylib" ]; then
            cp target/release/libvibeproxy_core.dylib "$BINDINGS_DIR/swift/"
        fi
        
        # Copy C header
        if [ -f "bindings/c/vibeproxy_core.h" ]; then
            cp bindings/c/vibeproxy_core.h "$BINDINGS_DIR/swift/"
        fi
        ;;
        
    Linux)
        echo "Building for Linux..."
        cargo build --release
        
        # Copy to bindings
        mkdir -p "$BINDINGS_DIR/c"
        if [ -f "target/release/libvibeproxy_core.so" ]; then
            cp target/release/libvibeproxy_core.so "$BINDINGS_DIR/c/"
        fi
        if [ -f "bindings/c/vibeproxy_core.h" ]; then
            cp bindings/c/vibeproxy_core.h "$BINDINGS_DIR/c/"
        fi
        ;;
        
    MINGW*|MSYS*|CYGWIN*)
        echo "Building for Windows..."
        cargo build --release --target x86_64-pc-windows-msvc
        
        # Copy to bindings
        mkdir -p "$BINDINGS_DIR/csharp"
        if [ -f "target/x86_64-pc-windows-msvc/release/vibeproxy_core.dll" ]; then
            cp target/x86_64-pc-windows-msvc/release/vibeproxy_core.dll "$BINDINGS_DIR/csharp/"
        fi
        ;;
        
    *)
        echo "Unknown platform: $(uname -s)"
        exit 1
        ;;
esac

echo "=== Build Complete ==="
echo ""
echo "Artifacts:"
ls -la "$CORE_DIR/target/release/"*.{dylib,so,dll} 2>/dev/null || true

