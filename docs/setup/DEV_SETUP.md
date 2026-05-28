# 🚀 VibeProxy Live Reload Development Setup

This guide sets up live reload for VibeProxy development, automatically rebuilding and updating the app when you make changes.

## Quick Start

### Option 1: Simple Live Reload (Recommended)
```bash
cd /Users/kooshapari/temp-PRODVERCEL/485/vibeproxy
./simple-live-reload.sh
```

### Option 2: Full Live Reload with fswatch
```bash
cd /Users/kooshapari/temp-PRODVERCEL/485/vibeproxy
./dev-live-reload.sh
```

## What You Need

### Prerequisites
- **Xcode Command Line Tools**: `xcode-select --install`
- **Homebrew**: For installing dependencies
- **One of these file watchers**:
  - `entr` (lightweight, recommended): `brew install entr`
  - `fswatch` (full-featured): `brew install fswatch`

## How It Works

1. **File Watching**: Monitors changes in:
   - `src/` directory (Swift source files)
   - `config.example.yaml` (configuration)
   - Any other files you specify

2. **Auto-Build**: When changes detected:
   - Cleans previous build (`rm -rf src/.build`)
   - Builds Swift app (`swift build`)
   - Creates app bundle (`./create-app-bundle.sh`)
   - Updates app in Applications folder

3. **Live Updates**: Your changes appear immediately:
   - App bundle updated in `/Applications/VibeProxy.app`
   - Binary updated with latest CLI proxy API
   - UI changes reflected instantly

## Development Workflow

### 1. Start Live Reload
```bash
# In one terminal
cd vibeproxy
./simple-live-reload.sh
```

### 2. Make Changes
Edit any Swift file:
- `src/Sources/SettingsView.swift`
- `src/Sources/ServiceItemView.swift`
- Any other `.swift` files

### 3. See Changes Live
- Changes automatically build and update
- App in Applications folder gets updated
- Open VibeProxy to see your changes

## What Gets Updated

### Swift Code Changes
- UI changes in SettingsView
- New ServiceItemView features
- Logic updates
- Bug fixes

### Binary Updates
- CLI proxy API improvements
- Gemini 3 Pro support
- New executor features
- Configuration changes

### App Bundle
- Updated Info.plist
- New Resources
- Code signing updates

## Notifications

The live reload system will show:
- ✅ Build success notifications
- ❌ Build failure notifications
- 📊 Binary size information
- 🔄 Rebuild status

## Customization

### Watch Additional Files
Edit `simple-live-reload.sh`:
```bash
# Add more files to watch
find src -name "*.swift" config.example.yaml your-file.yaml | entr -c ...
```

### Change Build Commands
Modify the `rebuild()` function:
```bash
# Add custom build steps
swift build
# Add your custom commands here
./create-app-bundle.sh
```

### Auto-Start App
The script can automatically open VibeProxy after each build:
```bash
# Add to rebuild function
open -a "VibeProxy"
```

## Troubleshooting

### Permission Issues
```bash
sudo chmod +x simple-live-reload.sh
```

### Missing Dependencies
```bash
# Install entr
brew install entr

# Install fswatch (alternative)
brew install fswatch
```

### Build Failures
Check the terminal output for Swift compilation errors and fix them.

### App Not Updating
- Check if `/Applications/VibeProxy.app` exists
- Verify build permissions
- Restart the live reload script

## Performance Tips

- **Use simple-live-reload.sh** for faster builds
- **Close Xcode** while using live reload to avoid conflicts
- **Minimal changes** rebuild faster than large changes

## Example Development Session

```bash
# 1. Start live reload
cd vibeproxy
./simple-live-reload.sh

# 2. Terminal shows:
# 🔨 Initial build...
# ✅ Swift build successful
# ✅ App bundle updated
# 🎯 Live reload active!

# 3. Edit src/Sources/SettingsView.swift
# (Save file - live reload detects change)

# 4. Terminal shows:
# 🔄 File change detected, rebuilding...
# ✅ Rebuild successful

# 5. Open VibeProxy from Applications to see changes!

# 6. Press Ctrl+C to stop live reload
```

## Benefits

✅ **Instant Feedback**: See changes immediately  
✅ **No Manual Building**: Automatic rebuilds  
✅ **Development Speed**: Faster iteration cycles  
✅ **Error Detection**: Immediate build error feedback  
✅ **Seamless Updates**: App automatically updated  

## Ready to Start?

```bash
cd /Users/kooshapari/temp-PRODVERCEL/485/vibeproxy
./simple-live-reload.sh
```

Start editing Swift files and watch your changes live! 🚀
