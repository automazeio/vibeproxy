# Changelog

All notable changes to VibeProxy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-11-22

### Added
- **Amp CLI Integration** - Full support for Amp CLI through VibeProxy
  - Smart path routing: `/auth/cli-login` → `/api/auth/cli-login` for authentication
  - Provider path rewriting: `/provider/*` → `/api/provider/*` for model requests
  - Management route forwarding to ampcode.com with Location header rewriting
  - Automatic fallback to Amp API when local OAuth tokens are unavailable
  - Seamless integration allowing Factory and Amp CLI through single proxy
- **New Setup Guide** - Comprehensive AMPCODE_SETUP.md with step-by-step instructions
  - Configuration of Amp URL and settings
  - Secrets file format conversion for CLIProxyAPI compatibility
  - Troubleshooting guide for common issues
- **Config Updates** - Added Amp upstream configuration
  - `amp-upstream-url`: https://ampcode.com
  - `amp-restrict-management-to-localhost`: true (security)

### Fixed
- **CLI Flag Fix** - Corrected `-config` flag in ServerManager (was incorrectly using `--config`)
  - Resolves "Could not start backend server on port 8318" errors
- **Token Expiry Handling** - Improved OAuth token expiry detection
  - System now correctly falls back to Amp API when local tokens expire
- **UI Duplicate** - Removed duplicate Antigravity entry in Settings view

### Changed
- **README Updates** - Added reference to new Amp CLI setup guide alongside Factory guide
- **Architecture** - Enhanced ThinkingProxy routing logic for multi-tool support
  - One proxy server now handles Factory CLI, Amp CLI, and future integrations

### Technical Details
- ThinkingProxy path rewrites apply before management route detection
- Location header rewriting in Amp responses ensures redirects work through proxy
- API key resolution from `~/.local/share/amp/secrets.json` for fallback requests
- Compatible with CLIProxyAPI 6.5.16's Amp module

## [1.1.0] - 2025-11-22

### Updated
- **CLIProxyAPI 6.5.16** - Latest upstream release with improvements and bug fixes
  - Various upstream improvements and stability enhancements

### Fixed
- **Auto-Update Workflow** - Improved file filtering to prevent unwanted files from CLIProxyAPI releases
  - Now explicitly excludes: README.md, LICENSE, config.example.yaml, config.yaml, README_CN.md
  - Prevents accidental overwriting of VibeProxy documentation files
  - Added debug output to detect unexpected extracted files

### Note
- Switched to semantic versioning: Minor version bump (1.1.0) for CLIProxyAPI updates that may include new features
- Future patch versions (1.1.x) will be for bug fixes only
- Future minor versions (1.x.0) will include new features or significant updates

## [1.0.9] - 2025-11-22

### Added
- **Antigravity OAuth Support** - Full integration with Google's Antigravity service for unified AI model access (#41)
  - Browser-based Antigravity OAuth authentication flow
  - Automatic credential management and token refresh
  - Connection status display with email and expiration tracking
  - Access to Gemini 3 Pro models via Antigravity backend
  
- **Gemini 3 Pro Models** - Support for Google's latest Gemini 3 models through Antigravity
  - `gemini-3-pro-high` - Maximum capability variant
  - `gemini-3-pro-low` - Standard variant (recommended)
  - `gemini-3-pro-image` - Enhanced vision capabilities
  - All models use OpenAI API format with Antigravity authentication

### Improved
- **Settings UI** - Reduced window height from 590px to 540px for more compact interface
- **Service Order** - Reordered services alphabetically with Antigravity first
- **Documentation** - Comprehensive Gemini 3 Pro setup guide with Antigravity authentication instructions
  - Updated FACTORY_SETUP.md with complete Antigravity configuration
  - Added important callouts about provider settings and authentication requirements
  - Updated README.md with Antigravity announcements and feature list

### Fixed
- **GitHub Action** - Fixed CLIProxyAPI auto-update workflow to correctly identify binary in tarball
  - Changed from using `head -n 1` to filtering out documentation files
  - Prevents LICENSE file from being misidentified as the binary

## [1.0.8] - 2025-11-21

### Fixed
- **Window Crash Bug** - Fixed critical crash when closing settings window on macOS 26.0.1 (#19)
  - Added NSWindowDelegate protocol and proper window lifecycle management
  - Made settingsWindow a weak reference to prevent memory issues
  - Added windowDidClose delegate method for cleanup

### Added
- **Qwen Models Documentation** - Added Qwen3 Coder Plus and Qwen3 Coder Flash to Factory setup guide (#21)
- **Gemini Models Documentation** - Comprehensive Gemini setup instructions for Factory CLI integration
  - Added working Gemini 2.5 models (Pro, Flash, Flash Lite)
  - Documented Gemini 3 Pro Preview status (requires Vertex AI API, support coming soon)

### Improved
- **Issue Triage** - Resolved 12 open issues with detailed responses and documentation updates
- **Documentation** - Clarified model availability, setup instructions, and troubleshooting

## [1.0.7] - 2025-11-21

### Updated
- **CLIProxyAPI 6.5.1** - Updated to latest upstream binary with bug fixes and improvements:
  - Fixed antigravity callback port to use fixed port 51121
  - Improved SSE usage filtering across streams
  - Fixed Gemini CLI to ignore thoughtSignature and empty parts

### Added
- **Auto-Update Workflow** - Added GitHub Action to automatically check for and update the bundled CLIProxyAPI binary
- **GPT-5.1 Docs** - Updated README and Factory setup instructions for `gpt-5.1*` and `gpt-5.1-codex*` models with Factory CLI

## [1.0.6] - 2025-10-15

### Added
- **Qwen Support** - Full integration with Qwen AI via OAuth authentication
  - Browser-based Qwen OAuth flow with automatic email submission
  - Pre-authentication email collection dialog for seamless UX
  - Automatic credential file creation with type: "qwen"
  - Connection status display with email and expiration tracking
  - Qwen added to end of service providers list

### Improved
- **Settings Window** - Increased height from 440px to 490px to accommodate Qwen service section

## [1.0.5] - 2025-10-14

### Added
- **Claude Thinking Proxy** - Transform Claude model requests with `-thinking-N` suffixes into Anthropic extended thinking calls
  - Dynamic budget parsing with suffix stripping and safe defaults for invalid values
  - Automatic token headroom management that respects Anthropic limits

### Fixed
- **Factory CLI Compatibility** - Forward all headers and honor connection lifecycle to prevent hangs and connection errors
- **Large Request Handling** - Preserve gzip responses and support payloads beyond 64KB without truncation

## [1.0.4] - 2025-10-14

### Added
- **Gemini Support** - Full integration with Google's Gemini AI via OAuth authentication
  - Browser-based Google OAuth flow for secure authentication
  - Automatic credential file creation (`{email}-{project}.json` with type: "gemini")
  - Project selection during authentication (auto-accepts default after 3 seconds)
  - Support for multiple Google Cloud projects
  - Connection status display with email and expiration tracking
  - Help tooltip explaining project selection behavior

- **Authentication Status System** - Unified credential monitoring for all services
  - `AuthManager` scans `~/.cli-proxy-api/` directory for credential files
  - Real-time file system monitoring for credential changes
  - Support for Claude Code, Codex, and Gemini with type-based detection
  - Expiration date tracking with visual indicators (green/red status)
  - Debug logging for troubleshooting authentication issues

### Improved
- **Settings Window** - Increased height from 380px to 440px
  - All three service sections now visible without scrolling
  - Better spacing and readability
  - Services displayed in alphabetical order: Claude Code, Codex, Gemini

- **Authentication Flow** - More reliable completion detection
  - Process termination handler triggers automatic credential refresh
  - Auto-send newline to stdin for non-interactive project selection
  - Better handling of OAuth callback completion
  - Prevents process hanging during project selection prompt

### Fixed
- **Gemini Authentication** - Resolved credential file creation issues
  - Correctly uses `-login` command for OAuth (vs `-gemini-web-auth` for cookies)
  - Credential files properly detected regardless of filename pattern
  - Authentication completion properly triggers UI refresh
  - Browser opens reliably for OAuth flow

## [1.0.3] - 2025-10-14

### Added
- **Icon Caching System** - New `IconCatalog` singleton for thread-safe icon caching
  - Eliminates redundant disk I/O for frequently accessed icons
  - Icons are preloaded on app launch to reduce first-use latency
  - Cached by name, size, and template flag for optimal reuse

- **Modern Notification System** - Migrated from deprecated `NSUserNotification` to `UNUserNotificationCenter`
  - Proper permission handling with user consent
  - Notifications display with banner and sound, including when app is in foreground
  - Permission state checked before sending notifications

### Improved
- **Server Lifecycle Management** - Enhanced reliability and async handling
  - Dedicated process queue for serialized server operations
  - Graceful shutdown with timeout and force-kill fallback
  - Readiness check after startup to verify server is operational
  - Async `stop()` method with optional completion callback

- **Service Disconnect Flow** - Streamlined and more reliable
  - Generic `performDisconnect()` method eliminates code duplication
  - Automatic server restart after credential removal
  - Better error messages for missing credentials

- **Log Buffer Performance** - Replaced array with O(1) ring buffer
  - Fixed-size circular buffer maintains constant memory footprint
  - Optimal for 1000-line log history

### Fixed
- **Menu Bar Icons** - More consistent sizing and reliable fallbacks to system icons
- Improved status updates and icon changes reflecting server state accurately

## [1.0.2] - 2025-10-06

### Fixed
- **Orphaned Process Cleanup** - App now automatically kills any orphaned server processes on startup
  - Prevents "port already in use" errors after app crashes
  - Detects and logs PIDs of orphaned processes before cleanup
  - Ensures clean server restart after unexpected app termination

## [1.0.1] - 2025-10-06

### Fixed
- Service icons (Codex and Claude Code) now display correctly in Settings view
- All resource paths corrected to work with bundled app structure

### Documentation
- Added Apple Silicon (M1/M2/M3/M4) requirement to README and installation guide
- Clarified that Intel Macs are not supported

## [1.0.0] - 2025-10-05

Initial release of VibeProxy - a native macOS menu bar application for managing CLIProxyAPI.

### Features

- **Native macOS Experience** - Clean SwiftUI interface with menu bar integration
- **One-Click Server Management** - Start/stop the proxy server from your menu bar
- **OAuth Integration** - Authenticate with Claude Code and Codex directly from the app
- **Real-Time Status** - Live connection status and automatic credential detection
- **Auto-Updates** - Monitors auth files and updates UI in real-time
- **Beautiful Icons** - Custom icons with dark mode support
- **Self-Contained** - Everything bundled inside the .app (server binary, config, static files)
- **Launch at Login** - Optional auto-start on macOS login
- **Factory AI Integration** - Easy setup guide for Factory Droids

### Technical

- Built on [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
- Code signed with Apple Developer ID
- Notarized for seamless installation
- Automated version injection from git tags
- Automated GitHub Actions release workflow

### Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3/M4) - Intel Macs are not supported

---

## Future Releases

All future changes will be documented here before release.

---

[1.0.7]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.7
[1.0.6]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.6
[1.0.5]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.5
[1.0.4]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.4
[1.0.3]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.3
[1.0.2]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.2
[1.0.1]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.1
[1.0.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.0
