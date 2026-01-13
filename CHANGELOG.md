# Changelog

All notable changes to VibeProxy will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.8.50] - 2026-01-13

### Fixed
- **Amp CLI Login Flow** - Fixed OAuth login failing with "403 Invalid state parameter"
  - Login now redirects directly to ampcode.com to preserve OAuth state cookies
  - Browser stays on ampcode.com during authentication for proper cookie handling
- **Amp CLI OAuth Integration** - Fixed "auth_unavailable" errors when using Amp CLI
  - Enabled local OAuth providers (Claude, Codex, Gemini) for Amp requests
  - Your subscriptions are now used instead of Amp credits when available
  - Automatic fallback to Amp upstream when no local OAuth token exists

### Added
- **Auto-fix Amp Secrets** - VibeProxy now automatically fixes the Amp secrets.json format on startup
  - Adds the `apiKey` field that CLIProxyAPI needs
  - No manual step required after `amp login`

### Changed
- **Amp Request Routing** - Improved routing logic for Amp management vs provider requests
  - Management requests (auth, user, threads) forwarded to ampcode.com
  - Provider requests routed through CLIProxyAPI for local OAuth support

## [1.8.49] - 2026-01-13

### Updated
- **CLIProxyAPI 6.6.103-0** - Latest upstream release (#164)
  - Various upstream improvements and stability enhancements


### Added
- **Z.AI GLM Provider Support** - Add Z.AI as a new provider for GLM models (#161)
  - Enter your Z.AI API key directly in the Settings UI
  - Supports GLM-4.7, GLM-4-Plus, GLM-4-Air, and GLM-4-Flash models
  - Get your API key at [z.ai](https://z.ai/manage-apikey/apikey-list)
  - Uses OpenAI-compatible endpoint for seamless integration
- **Edit menu** - Added standard Edit menu for keyboard shortcuts (Cmd+C/V/X/A)

### Fixed
- **YAML escaping** - API keys with special characters are now properly escaped


## [1.8.47] - 2026-01-12
### Updated
- **CLIProxyAPI 6.6.100-0** - Latest upstream release (#163)
  - Various upstream improvements and stability enhancements


## [1.8.46] - 2026-01-10

### Updated
- **CLIProxyAPI 6.6.98-0** - Latest upstream release (#162)
  - Various upstream improvements and stability enhancements

## [1.8.45] - 2026-01-10

### Updated
- **CLIProxyAPI 6.6.96-0** - Latest upstream release (#160)
  - Various upstream improvements and stability enhancements


## [1.8.44] - 2026-01-09

### Updated
- **CLIProxyAPI 6.6.92-0** - Latest upstream release (#158)
  - Various upstream improvements and stability enhancements


## [1.8.43] - 2026-01-08

### Updated
- **CLIProxyAPI 6.6.90-0** - Latest upstream release (#155)
  - Various upstream improvements and stability enhancements


## [1.8.42] - 2026-01-07

### Updated
- **CLIProxyAPI 6.6.88-0** - Latest upstream release (#150)
  - Various upstream improvements and stability enhancements


## [1.8.41] - 2026-01-07

### Updated
- **CLIProxyAPI 6.6.86-0** - Latest upstream release (#149)
  - Various upstream improvements and stability enhancements


## [1.8.40] - 2026-01-05

### Added
- **Claude models via Antigravity** - Support for `gemini-claude-*` model prefixes (#145)
  - `gemini-claude-opus-4-5-thinking`, `gemini-claude-sonnet-4-5-thinking`, etc.
  - Enables extended thinking with Antigravity authentication

### Fixed
- **Codex login timeout** - Fix login hanging when Google account selection takes >15 seconds (#123)
- **ThinkingProxy model matching** - More precise detection of thinking models

### Improved
- **Settings UI** - Services with expired accounts now auto-expand to draw attention


## [1.8.39] - 2026-01-05

### Updated
- **CLIProxyAPI 6.6.84-0** - Latest upstream release (#144)
  - Various upstream improvements and stability enhancements


## [1.8.38] - 2026-01-04

### Updated
- **CLIProxyAPI 6.6.82-0** - Latest upstream release (#143)
  - Various upstream improvements and stability enhancements


## [1.8.37] - 2026-01-04

### Updated
- **CLIProxyAPI 6.6.81-0** - Latest upstream release (#142)
  - Various upstream improvements and stability enhancements


## [1.8.36] - 2026-01-03

### Updated
- **CLIProxyAPI 6.6.80-0** - Latest upstream release (#139)
  - Various upstream improvements and stability enhancements


## [1.8.35] - 2026-01-02

### Updated
- **CLIProxyAPI 6.6.77-1** - Latest upstream release (#138)
  - Various upstream improvements and stability enhancements


## [1.8.34] - 2025-12-31

### Updated
- **CLIProxyAPI 6.6.73-0** - Latest upstream release (#137)
  - Various upstream improvements and stability enhancements


## [1.8.33] - 2025-12-31

### Updated
- **CLIProxyAPI 6.6.71-0** - Latest upstream release (#135)
  - Various upstream improvements and stability enhancements


## [1.8.32] - 2025-12-30

### Updated
- **CLIProxyAPI 6.6.69-0** - Latest upstream release (#134)
  - Various upstream improvements and stability enhancements


## [1.8.31] - 2025-12-30

### Updated
- **CLIProxyAPI 6.6.68-0** - Latest upstream release (#133)
  - Various upstream improvements and stability enhancements


## [1.8.30] - 2025-12-28

### Updated
- **CLIProxyAPI 6.6.63-0** - Latest upstream release (#131)
  - Various upstream improvements and stability enhancements


## [1.8.29] - 2025-12-28

### Updated
- **CLIProxyAPI 6.6.62-0** - Latest upstream release (#130)
  - Various upstream improvements and stability enhancements


## [1.8.28] - 2025-12-27

### Updated
- **CLIProxyAPI 6.6.58-0** - Latest upstream release (#127)
  - Various upstream improvements and stability enhancements


## [1.8.27] - 2025-12-26

### Updated
- **CLIProxyAPI 6.6.56-0** - Latest upstream release (#126)
  - Various upstream improvements and stability enhancements


## [1.8.26] - 2025-12-26

### Updated
- **CLIProxyAPI 6.6.55-0** - Latest upstream release (#124)
  - Various upstream improvements and stability enhancements


## [1.8.25] - 2025-12-25

### Updated
- **CLIProxyAPI 6.6.53-0** - Latest upstream release (#122)
  - Various upstream improvements and stability enhancements


## [1.8.24] - 2025-12-24

### Updated
- **CLIProxyAPI 6.6.50-2** - Latest upstream release (#121)
  - Various upstream improvements and stability enhancements


## [1.8.23] - 2025-12-24

### Updated
- **CLIProxyAPI 6.6.49-0** - Latest upstream release (#119)
  - Various upstream improvements and stability enhancements


## [1.8.22] - 2025-12-23

### Updated
- **CLIProxyAPI 6.6.47-0** - Latest upstream release (#118)
  - Various upstream improvements and stability enhancements


## [1.8.21] - 2025-12-23

### Updated
- **CLIProxyAPI 6.6.46-0** - Latest upstream release (#117)
  - Various upstream improvements and stability enhancements


## [1.8.20] - 2025-12-22

### Updated
- **CLIProxyAPI 6.6.41-0** - Latest upstream release (#116)
  - Various upstream improvements and stability enhancements


## [1.8.19] - 2025-12-21

### Updated
- **CLIProxyAPI 6.6.40-0** - Latest upstream release (#115)
  - Various upstream improvements and stability enhancements


## [1.8.18] - 2025-12-21

### Updated
- **CLIProxyAPI 6.6.38-0** - Latest upstream release (#114)
  - Various upstream improvements and stability enhancements


## [1.8.17] - 2025-12-20

### Updated
- **CLIProxyAPI 6.6.35-0** - Latest upstream release (#112)
  - Various upstream improvements and stability enhancements


## [1.8.16] - 2025-12-20

### Updated
- **CLIProxyAPI 6.6.34-0** - Latest upstream release (#109)
  - Various upstream improvements and stability enhancements


## [1.8.15] - 2025-12-19

### Updated
- **CLIProxyAPI 6.6.29-1** - Latest upstream release (#107)
  - Various upstream improvements and stability enhancements


## [1.8.14] - 2025-12-18

### Updated
- **CLIProxyAPI 6.6.26-0** - Latest upstream release (#102)
  - Various upstream improvements and stability enhancements


## [1.8.13] - 2025-12-18

### Updated
- **CLIProxyAPI 6.6.25-1** - Latest upstream release (#101)
  - Various upstream improvements and stability enhancements


## [1.8.12] - 2025-12-17

### Updated
- **CLIProxyAPI 6.6.22-0** - Latest upstream release (#100)
  - Various upstream improvements and stability enhancements


## [1.8.11] - 2025-12-17

### Updated
- **CLIProxyAPI 6.6.20-0** - Latest upstream release (#98)
  - Various upstream improvements and stability enhancements


## [1.8.10] - 2025-12-16

### Updated
- **CLIProxyAPI 6.6.17-0** - Latest upstream release (#95)
  - Various upstream improvements and stability enhancements


## [1.8.9] - 2025-12-15

### Added
- **Interleaved Thinking Support** - ThinkingProxy now automatically adds the `anthropic-beta: interleaved-thinking-2025-05-14` header when extended thinking is enabled via the `-thinking-*` model suffix. This allows Claude to reason between tool calls for better multi-step coding tasks.

### Updated
- **Documentation** - Updated FACTORY_SETUP.md with GPT 5.2 models and corrected reasoning effort syntax (use parentheses like `gpt-5.2(high)` instead of dashes)


## [1.8.8] - 2025-12-15

### Updated
- **CLIProxyAPI 6.6.14-0** - Latest upstream release (#93)
  - Various upstream improvements and stability enhancements


## [1.8.7] - 2025-12-14

### Updated
- **CLIProxyAPI 6.6.9-1** - Latest upstream release (#92)
  - Various upstream improvements and stability enhancements


## [1.8.6] - 2025-12-13

### Updated
- **CLIProxyAPI 6.6.8-1** - Latest upstream release (#90)
  - Various upstream improvements and stability enhancements


## [1.8.5] - 2025-12-12

### Updated
- **CLIProxyAPI 6.6.5-0** - Latest upstream release (#86)
  - Various upstream improvements and stability enhancements


## [1.8.4] - 2025-12-11

### Updated
- **CLIProxyAPI 6.6.0-1** - Latest upstream release (#84)
  - Various upstream improvements and stability enhancements


## [1.8.3] - 2025-12-10

### Updated
- **CLIProxyAPI 6.5.63-1** - Latest upstream release (#82)
  - Various upstream improvements and stability enhancements


## [1.8.2] - 2025-12-09

### Updated
- **CLIProxyAPI 6.5.58-0** - Latest upstream release (#78)
  - Various upstream improvements and stability enhancements


This release is all about code improvements and standartization. No user-facing changes.

### Fixed
- Race condition in ThinkingProxy stop() method
- Memory leak in pipe handlers (ServerManager and TunnelManager)
- Thread safety issue in TunnelManager URL detection

### Changed
- Minimum macOS version raised to 14.0 (Sonoma)
- Extracted magic numbers to configuration constants
- Replaced force unwraps with proper error handling
- Centralized notification names into type-safe constants
- Made date formatters static for better performance
- Standardized logging to use NSLog throughout


## [1.8.0] - 2025-12-08

### Added
- **GitHub Copilot Support** - Connect your GitHub Copilot subscription for access to Claude, GPT, Gemini and other models

### Changed
- Switched from CLIProxyAPI to CLIProxyAPIPlus for third-party provider support
- Device code now copied with hyphen for easier GitHub authentication

### Updated
- **CLIProxyAPIPlus 6.5.55** - Latest upstream release


## [1.7.0] - 2025-12-08

### Added
- **Multi-Account Support** - Connect multiple accounts per provider (#70)
  - Automatic round-robin distribution across accounts
  - Auto-failover when an account hits rate limits
  - Collapsible account lists in settings UI
  - Per-account removal with confirmation dialog

### Changed
- Improved settings UI with cleaner account management
- Binds CLIProxyAPI to localhost only for improved security (#75)


## [1.6.6] - 2025-12-08

### Updated
- **CLIProxyAPI 6.5.55** - Latest upstream release (#76)
  - Various upstream improvements and stability enhancements


## [1.6.5] - 2025-12-07

### Updated
- **CLIProxyAPI 6.5.53** - Latest upstream release (#73)
  - Various upstream improvements and stability enhancements


## [1.6.4] - 2025-12-06

### Updated
- **CLIProxyAPI 6.5.49** - Latest upstream release (#71)
  - Various upstream improvements and stability enhancements


## [1.6.3] - 2025-12-05

### Updated
- **CLIProxyAPI 6.5.42** - Latest upstream release (#68)
  - Various upstream improvements and stability enhancements


## [1.6.2] - 2025-12-04

### Updated
- **CLIProxyAPI 6.5.38** - Latest upstream release (#66)
  - Various upstream improvements and stability enhancements


## [1.6.1] - 2025-12-03

### Updated
- **CLIProxyAPI 6.5.36** - Latest upstream release (#65)
  - Various upstream improvements and stability enhancements

## [1.6.0] - 2025-12-02

### Added
- **Automatic App Updates** - Sparkle integration for seamless app updates (#59)
  - Check for updates daily automatically
  - Manual "Check for Updates..." menu item in the menu bar
  - Secure EdDSA signed updates
  - Fully automated: new CLIProxyAPI versions are detected, built, signed, notarized, and published automatically

## [1.5.3] - [1.5.7] - 2025-12-02

### Internal
- **Auto-Update Testing** - Internal releases for testing and refining the Sparkle auto-update integration
  - 1.5.3: Initial Sparkle integration
  - 1.5.4: Version comparison fixes
  - 1.5.5: Build number calculation fixes
  - 1.5.6: XPC entitlements for installer permissions
  - 1.5.7: Final verification release

## [1.5.2] - 2025-12-02

### Updated
- **CLIProxyAPI 6.5.32** - Latest upstream release (#64)
  - Various upstream improvements and stability enhancements

## [1.5.1] - 2025-12-01

### Updated
- **CLIProxyAPI 6.5.31** - Latest upstream release (#63)
  - Various upstream improvements and stability enhancements

## [1.5.0] - 2025-11-28

### Updated
- **CLIProxyAPI 6.5.27** - Latest upstream release (#58)
  - Various upstream improvements and stability enhancements

## [1.4.1] - 2025-11-27

### Updated
- **CLIProxyAPI 6.5.26** - Latest upstream release (#56)
  - Various upstream improvements and stability enhancements

## [1.4.0] - 2025-11-26

### Added
- **GPT-5.1 Codex Max Support** - Added configuration and documentation for OpenAI's latest Codex Max model (#54)
  - `gpt-5.1-codex-max` - Optimized for long-horizon agentic coding tasks
  - Complete setup instructions in FACTORY_SETUP.md

### Updated
- **CLIProxyAPI 6.5.23** - Latest upstream release (#55)
  - Includes support for Gemini 3 Pro Image Preview model
  - Various upstream improvements and stability enhancements

### Fixed
- **Gemini 3 Pro Model Names** - Corrected model names to match CLIProxyAPI supported models (#53)
  - Changed `gemini-3-pro-high` / `gemini-3-pro-low` to `gemini-3-pro-preview`
  - Changed `gemini-3-pro-image` to `gemini-3-pro-image-preview`
  - Updated FACTORY_SETUP.md and CHANGELOG.md with correct model names
- **Auto-Update Workflow** - Fixed YAML syntax error in PR notification step
  - Fixed multi-line string indentation in `update-cliproxyapi.yml`
  - Workflow now runs successfully instead of failing immediately
  - Added PR comments with @mentions for better notification delivery

## [1.3.0] - 2025-11-25

### Added
- **Claude Opus 4.5 Support** - Full documentation for Claude's latest Opus 4.5 model
  - Added `claude-opus-4-5-20251101` base model configuration
  - Added extended thinking variants: `-thinking-4000`, `-thinking-10000`, `-thinking-32000`
  - Complete setup instructions in FACTORY_SETUP.md
  - Available through bundled CLIProxyAPI 6.5.18+

### Fixed
- **Auto-Update Workflow** - Major improvements to prevent file corruption (#47)
  - Now uses temporary directory for tarball extraction (prevents repo contamination)
  - Added trap-based cleanup for robust error handling
  - Validates that only cli-proxy-api binary is modified before committing
  - Auto-closes old unmerged bump PRs to prevent accumulation
  - Prevents accidental deletion of README.md and LICENSE files
- **Documentation Recovery** - Restored README.md and LICENSE files
  - Files were accidentally deleted in auto-update PR #52
  - Restored from v1.2.0 tag with latest Amp CLI setup guide references

### Changed
- **Workflow Reliability** - Enhanced auto-update workflow maintainability
  - Replaced 8 manual cleanup calls with single trap handler
  - Better error handling for all failure paths
  - Cleaner git commits with validation checks

### Technical Details
- Auto-update workflow now extracts to `mktemp -d` temporary directory
- Trap ensures cleanup on both success and failure
- Git status validation prevents unintended file modifications
- Workflow fixes prevent issues seen in PR #46 and #49

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
- Compatible with CLIProxyAPI 6.5.7's Amp module

## [1.1.0] - 2025-11-22

### Updated
- **CLIProxyAPI 6.5.7** - Latest upstream release with improvements and bug fixes
  - Commit: 9d50a68, Built: 2025-11-22T13:36:45Z
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
  - `gemini-3-pro-preview` - Latest preview model (recommended)
  - `gemini-3-pro-image-preview` - Enhanced vision capabilities
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

[1.8.49]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.49
[1.8.47]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.47
[1.8.46]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.46
[1.8.45]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.45
[1.8.44]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.44
[1.8.43]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.43
[1.8.42]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.42
[1.8.41]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.41
[1.8.39]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.39
[1.8.38]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.38
[1.8.37]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.37
[1.8.36]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.36
[1.8.35]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.35
[1.8.34]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.34
[1.8.33]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.33
[1.8.32]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.32
[1.8.31]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.31
[1.8.30]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.30
[1.8.29]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.29
[1.8.28]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.28
[1.8.27]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.27
[1.8.26]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.26
[1.8.25]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.25
[1.8.24]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.24
[1.8.23]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.23
[1.8.22]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.22
[1.8.21]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.21
[1.8.20]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.20
[1.8.19]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.19
[1.8.18]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.18
[1.8.17]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.17
[1.8.16]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.16
[1.8.15]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.15
[1.8.14]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.14
[1.8.13]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.13
[1.8.12]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.12
[1.8.11]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.11
[1.8.10]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.10
[1.8.8]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.8
[1.8.7]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.7
[1.8.6]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.6
[1.8.5]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.5
[1.8.4]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.4
[1.8.3]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.3
[1.8.2]: https://github.com/automazeio/vibeproxy/releases/tag/v1.8.2
[1.7.1]: https://github.com/automazeio/vibeproxy/releases/tag/v1.7.1
[1.6.6]: https://github.com/automazeio/vibeproxy/releases/tag/v1.6.6
[1.6.5]: https://github.com/automazeio/vibeproxy/releases/tag/v1.6.5
[1.6.4]: https://github.com/automazeio/vibeproxy/releases/tag/v1.6.4
[1.6.3]: https://github.com/automazeio/vibeproxy/releases/tag/v1.6.3
[1.6.2]: https://github.com/automazeio/vibeproxy/releases/tag/v1.6.2
[1.6.1]: https://github.com/automazeio/vibeproxy/releases/tag/v1.6.1
[1.6.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.6.0
[1.5.3] - [1.5.7]: https://github.com/automazeio/vibeproxy/releases/tag/v1.5.7
[1.5.2]: https://github.com/automazeio/vibeproxy/releases/tag/v1.5.2
[1.5.1]: https://github.com/automazeio/vibeproxy/releases/tag/v1.5.1
[1.5.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.5.0
[1.4.1]: https://github.com/automazeio/vibeproxy/releases/tag/v1.4.1
[1.4.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.4.0
[1.3.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.3.0
[1.2.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.2.0
[1.1.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.1.0
[1.0.9]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.9
[1.0.8]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.8
[1.0.7]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.7
[1.0.6]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.6
[1.0.5]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.5
[1.0.4]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.4
[1.0.3]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.3
[1.0.2]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.2
[1.0.1]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.1
[1.0.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.0
