# VibeProxy

<p align="center">
  <img src="icon.png" width="128" height="128" alt="VibeProxy Icon">
</p>

<p align="center">
<a href="https://automaze.io" rel="nofollow"><img alt="Automaze" src="https://img.shields.io/badge/By-automaze.io-4b3baf" style="max-width: 100%;"></a>
<a href="https://github.com/automazeio/vibeproxy/blob/main/LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-28a745" style="max-width: 100%;"></a>
<a href="http://x.com/intent/follow?screen_name=aroussi" rel="nofollow"><img alt="Follow on 𝕏" src="https://img.shields.io/badge/Follow-%F0%9D%95%8F/@aroussi-1c9bf0" style="max-width: 100%;"></a>
<a href="https://github.com/automazeio/vibeproxy"><img alt="Star this repo" src="https://img.shields.io/github/stars/automazeio/vibeproxy.svg?style=social&amp;label=Star%20this%20repo&amp;maxAge=60" style="max-width: 100%;"></a></p>
</p>

**Stop paying twice for AI.** VibeProxy is a beautiful native macOS menu bar app that lets you use your existing Claude Code, ChatGPT, **Gemini**, and **Qwen** subscriptions with powerful AI coding tools like **[Factory Droids](https://app.factory.ai/r/FM8BJHFQ)** – no separate API keys required.

Built on [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), it handles OAuth authentication, token management, and API routing automatically. One click to authenticate, zero friction to code.

> [!IMPORTANT]
> **NEW: Gemini and Qwen Support! 🎉** VibeProxy now supports Google's Gemini AI and Qwen AI with full OAuth authentication. Connect your accounts and use Gemini and Qwen with your favorite AI coding tools!

> [!IMPORTANT]
> **NEW: Extended Thinking Support! 🧠** VibeProxy now supports Claude's extended thinking feature with dynamic budgets (4K, 10K, 32K tokens). Use model names like `claude-sonnet-4-5-20250929-thinking-10000` to enable extended thinking. See the [Factory Setup Guide](FACTORY_SETUP.md#step-3-configure-factory-cli) for details.

> [!IMPORTANT]
> **NEW: Auto-Updates! 🔄** VibeProxy now automatically checks for and downloads the latest CLIProxyAPI binary updates in the background. You'll always have support for the newest models without lifting a finger.

> [!IMPORTANT]
> **NEW: GPT-5.1 & GPT-5.1 Codex Support! ⚡️** Drop the brand-new `gpt-5.1*` and `gpt-5.1-codex*` models into your Factory CLI config and VibeProxy will route them through your ChatGPT subscription automatically. Follow the updated [Factory setup](FACTORY_SETUP.md#step-3-configure-factory-cli) snippet.

<p align="center">
<br>
  <a href="https://www.loom.com/share/5cf54acfc55049afba725ab443dd3777"><img src="vibeproxy-factory-video.webp" width="600" height="380" alt="VibeProxy Screenshot" border="0"></a>
</p>

> [!TIP]
> Check out our [Factory Setup Guide](FACTORY_SETUP.md) for step-by-step instructions on how to use VibeProxy with Factory Droids.


## Features

- 🎯 **Native macOS Experience** - Clean, native SwiftUI interface that feels right at home on macOS
- 🚀 **One-Click Server Management** - Start/stop the proxy server from your menu bar
- 🔐 **OAuth Integration** - Authenticate with Codex, Claude Code, Gemini, and Qwen directly from the app
- 📊 **Real-Time Status** - Live connection status and automatic credential detection
- 🔄 **Auto-Updates** - Monitors auth files and updates UI in real-time
- 🎨 **Beautiful Icons** - Custom icons with dark mode support
- 💾 **Self-Contained** - Everything bundled inside the .app (server binary, config, static files)


## Installation

**⚠️ Requirements:** macOS running on **Apple Silicon only** (M1/M2/M3/M4 Macs). Intel Macs are not supported.

### Download Pre-built Release (Recommended)

1. Go to the [**Releases**](https://github.com/automazeio/vibeproxy/releases) page
2. Download the latest `VibeProxy.zip`
3. Extract and drag `VibeProxy.app` to `/Applications`
4. Launch VibeProxy

**Code Signed & Notarized** ✅ - No Gatekeeper warnings, installs seamlessly on macOS.

### Build from Source

Want to build it yourself? See [**INSTALLATION.md**](INSTALLATION.md) for detailed build instructions.

## Usage

### First Launch

1. Launch VibeProxy - you'll see a menu bar icon
2. Click the icon and select "Open Settings"
3. The server will start automatically
4. Click "Connect" for Claude Code, Codex, Gemini, or Qwen to authenticate

### Authentication

When you click "Connect":
1. Your browser opens with the OAuth page
2. Complete the authentication in the browser
3. VibeProxy automatically detects your credentials
4. Status updates to show you're connected

### Server Management

- **Toggle Server**: Click the status (Running/Stopped) to start/stop
- **Menu Bar Icon**: Shows active/inactive state
- **Launch at Login**: Toggle to start VibeProxy automatically

## Requirements

- macOS 13.0 (Ventura) or later

## Development

### Project Structure

```
VibeProxy/
├── Sources/
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Menu bar & window management
│   ├── ServerManager.swift     # Server process control & auth
│   ├── SettingsView.swift      # Main UI
│   ├── AuthStatus.swift        # Auth file monitoring
│   └── Resources/
│       ├── AppIcon.iconset     # App icon
│       ├── AppIcon.icns        # App icon
│       ├── cli-proxy-api       # CLIProxyAPI binary
│       ├── config.yaml         # CLIProxyAPI config
│       ├── icon-active.png     # Menu bar icon (active)
│       ├── icon-inactive.png   # Menu bar icon (inactive)
│       ├── icon-claude.png     # Claude Code service icon
│       ├── icon-codex.png      # Codex service icon
│       ├── icon-gemini.png     # Gemini service icon
│       └── icon-qwen.png       # Qwen service icon
├── Package.swift               # Swift Package Manager config
├── Info.plist                  # macOS app metadata
├── build.sh                    # Resource bundling script
├── create-app-bundle.sh        # App bundle creation script
└── Makefile                    # Build automation
```

### Key Components

- **AppDelegate**: Manages the menu bar item and settings window lifecycle
- **ServerManager**: Controls the cli-proxy-api server process and OAuth authentication
- **SettingsView**: SwiftUI interface with native macOS design
- **AuthStatus**: Monitors `~/.cli-proxy-api/` for authentication files
- **File Monitoring**: Real-time updates when auth files are added/removed

## Credits

VibeProxy is built on top of [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), an excellent unified proxy server for AI services.

Special thanks to the CLIProxyAPI project for providing the core functionality that makes VibeProxy possible.

## License

MIT License - see LICENSE file for details

## Support

- **Report Issues**: [GitHub Issues](https://github.com/automazeio/vibeproxy/issues)
- **Website**: [automaze.io](https://automaze.io)

---

© 2025 [Automaze, Ltd.](https://automaze.io) All rights reserved.
