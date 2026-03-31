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

**Stop paying twice for AI.** VibeProxy is a beautiful native macOS menu bar app that lets you use your existing Claude Code, ChatGPT, **Gemini**, **Qwen**, **Antigravity**, and **Z.AI GLM** subscriptions with powerful AI coding tools like **[Factory Droids](https://app.factory.ai/r/FM8BJHFQ)** – no separate API keys required.

Built on [CLIProxyAPIPlus](https://github.com/router-for-me/CLIProxyAPIPlus), it handles OAuth authentication, token management, and API routing automatically. One click to authenticate, zero friction to code.


<p align="center">
<br>
  <a href="https://www.loom.com/share/5cf54acfc55049afba725ab443dd3777"><img src="vibeproxy-factory-video.webp" width="600" height="380" alt="VibeProxy Screenshot" border="0"></a>
</p>

> [!TIP]
> 📣 **NEW: Vercel AI Gateway Integration!**<br>Route your Claude requests through [Vercel's officially sanctioned AI Gateway](https://vercel.com/docs/ai-gateway) for safer access to your Claude Max subscription. No more worrying about account risks from using OAuth tokens directly!
>
> **Latest models supported:** Gemini 3 Pro (via Antigravity), GPT-5.1 / GPT-5.1 Codex, Claude Sonnet 4.5 / Opus 4.5 with extended thinking, GitHub Copilot, and Z.AI GLM-4.7! 🚀 
> 
> **Setup Guides:**
> - [Factory CLI Setup →](FACTORY_SETUP.md) - Use Factory Droids with your AI subscriptions
> - [Amp CLI Setup →](AMPCODE_SETUP.md) - Use Amp CLI with fallback to your subscriptions

---

## Features

- 🎯 **Native macOS Experience** - Clean, native SwiftUI interface that feels right at home on macOS
- 🚀 **One-Click Server Management** - Start/stop the proxy server from your menu bar
- 🔐 **Easy Authentication** - Authenticate with Codex, Claude Code, Gemini, Qwen, Antigravity (OAuth), and Z.AI GLM (API key) directly from the app
- 🛡️ **Vercel AI Gateway** - Route Claude requests through [Vercel's AI Gateway](https://vercel.com/docs/ai-gateway) for safer access to your Claude Max subscription without risking your account from direct OAuth token usage
- 👥 **Multi-Account Support** - Connect multiple accounts per provider with automatic round-robin distribution and failover when rate-limited
- 🎚️ **Provider Priority** - Enable/disable providers to control which models are available (instant hot reload)
- 📊 **Real-Time Status** - Live connection status and automatic credential detection
- 🔄 **Automatic App Updates** - Starting with v1.6, VibeProxy checks for updates daily and installs them seamlessly via Sparkle
- 🎨 **Beautiful Icons** - Custom icons with dark mode support
- 💾 **Self-Contained** - Everything bundled inside the .app (server binary, config, static files)

**Composio Pattern**: ✅ Already compliant - Uses CLIProxyAPIPlus backend with swappable provider support (Claude, ChatGPT, Gemini, Qwen, Antigravity, Z.AI GLM)


## Installation

**Requirements:** macOS 13+ (Ventura or later)

### Download Pre-built Release (Recommended)

1. Go to the [**Releases**](https://github.com/automazeio/vibeproxy/releases) page
2. Download the appropriate version for your Mac:
   - **Apple Silicon** (M1/M2/M3/M4): `VibeProxy-arm64.zip`
   - **Intel**: `VibeProxy-x86_64.zip` *(untested - please report issues)*
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
4. Click "Connect" for Claude Code, Codex, Gemini, Qwen, or Antigravity to authenticate, or "Add Account" for Z.AI GLM to enter your API key

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
│       ├── cli-proxy-api-plus  # CLIProxyAPIPlus binary
│       ├── config.yaml         # CLIProxyAPIPlus config
│       ├── icon-active.png     # Menu bar icon (active)
│       ├── icon-inactive.png   # Menu bar icon (inactive)
│       ├── icon-claude.png     # Claude Code service icon
│       ├── icon-codex.png      # Codex service icon
│       ├── icon-gemini.png     # Gemini service icon
│       ├── icon-qwen.png       # Qwen service icon
│       └── icon-zai.png        # Z.AI GLM service icon
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

VibeProxy is built on top of [CLIProxyAPIPlus](https://github.com/router-for-me/CLIProxyAPIPlus), an excellent unified proxy server for AI services with support for third-party providers.

Special thanks to the CLIProxyAPIPlus project for providing the core functionality that makes VibeProxy possible.

## License

MIT License - see LICENSE file for details

## Support

- **Report Issues**: [GitHub Issues](https://github.com/automazeio/vibeproxy/issues)
- **Website**: [automaze.io](https://automaze.io)

---

© 2025 [Automaze, Ltd.](https://automaze.io) All rights reserved.
