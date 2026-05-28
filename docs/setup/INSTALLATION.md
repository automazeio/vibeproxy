# Installing VibeProxy

**⚠️ Requirements:** macOS running on **Apple Silicon only** (M1/M2/M3/M4 Macs). Intel Macs are not supported.

## Option 1: Download Pre-built Release (Recommended)

### Step 1: Download

1. Go to the [**Releases**](https://github.com/automazeio/vibeproxy/releases) page
2. Download the latest `VibeProxy.zip`
3. Extract the ZIP file

### Step 2: Install

**Choose your preferred method:**

**Via ZIP:**
1. Drag `VibeProxy.app` to your `/Applications` folder
2. Double-click to launch

**Via DMG (if available):**
1. Double-click `VibeProxy.dmg` to mount
2. Drag `VibeProxy.app` to the Applications folder shortcut
3. Eject the DMG
4. Launch VibeProxy from Applications

### Step 3: Launch

Double-click `VibeProxy.app` - it will launch immediately with no warnings! ✅

**Why?** VibeProxy releases are **code signed** with an Apple Developer ID and **notarized** by Apple, ensuring a seamless installation experience.

---

## Option 2: Build from Source

### Prerequisites

- macOS 13.0 (Ventura) or later
- Swift 5.9+
- Xcode Command Line Tools
- Git

### Build Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/automazeio/vibeproxy.git
   cd vibeproxy
   ```

2. **Build the app**
   ```bash
   ./create-app-bundle.sh
   ```

   This will:
   - Build the Swift executable in release mode
   - Download and bundle CLIProxyAPI
   - Create `VibeProxy.app`
   - Sign it with your Developer ID (if available)

3. **Install**
   ```bash
   # Move to Applications folder
   mv VibeProxy.app /Applications/

   # Or run directly
   open VibeProxy.app
   ```

### Build Commands

```bash
# Quick build and run
make run

# Build .app bundle
make app

# Install to /Applications
make install

# Clean build artifacts
make clean
```

### Code Signing (Optional)

If you have an Apple Developer account, the build script will automatically detect and use your Developer ID certificate for signing.

To manually specify a certificate:
```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./create-app-bundle.sh
```

---

## Verifying Downloads

Before installing any downloaded app, verify its authenticity:

### 1. Download from Official Source

Only download from the official [GitHub Releases](https://github.com/automazeio/vibeproxy/releases) page.

### 2. Verify Checksum (Optional)

Each release includes SHA-256 checksums:

```bash
# Download the checksum file
curl -LO https://github.com/automazeio/vibeproxy/releases/download/vX.X.X/VibeProxy.zip.sha256

# Verify the download
shasum -a 256 -c VibeProxy.zip.sha256
```

Expected output: `VibeProxy.zip: OK`

### 3. Inspect the Code

All source code is available in this repository - feel free to review before building.

---

## Troubleshooting

### "App is damaged and can't be opened"

This can happen if download quarantine attributes cause issues:

```bash
xattr -cr /Applications/VibeProxy.app
```

Then try opening again.

### Build Fails

**Error: Swift not found**
```bash
# Install Xcode Command Line Tools
xcode-select --install
```

**Error: Permission denied**
```bash
# Make scripts executable
chmod +x build.sh create-app-bundle.sh
```

### Still Having Issues?

- **Check System Requirements**: macOS 13.0 (Ventura) or later
- **Check Logs**: Look for errors in Console.app (search for "VibeProxy")
- **Report an Issue**: [GitHub Issues](https://github.com/automazeio/vibeproxy/issues)

---

**Questions?** Open an [issue](https://github.com/automazeio/vibeproxy/issues) or check the [README](README.md).
