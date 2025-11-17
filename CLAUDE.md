# CLAUDE.md - AI Assistant Guide for VibeProxy

## Project Overview

**VibeProxy** is a native macOS menu bar application that enables users to use their existing Claude Code, ChatGPT, Gemini, and Qwen subscriptions with AI coding tools like Factory Droids - without requiring separate API keys.

**Key Value Proposition:** Stop paying twice for AI - use your existing subscriptions through OAuth authentication.

**Built on:** [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) - handles OAuth authentication, token management, and API routing.

**Platform:** macOS 13.0+ (Ventura or later), Apple Silicon only (M1/M2/M3/M4)

## Repository Structure

```
VibeProxy/
├── src/                          # Swift source code
│   ├── Sources/
│   │   ├── main.swift           # App entry point
│   │   ├── AppDelegate.swift    # Menu bar & orchestration
│   │   ├── ServerManager.swift  # Backend process management
│   │   ├── ThinkingProxy.swift  # HTTP proxy for extended thinking
│   │   ├── TunnelManager.swift  # Cloudflare tunnel integration
│   │   ├── SettingsView.swift   # SwiftUI settings UI
│   │   ├── AuthStatus.swift     # Auth state models
│   │   ├── IconCatalog.swift    # Image caching singleton
│   │   └── Resources/           # Bundled assets
│   │       ├── cli-proxy-api    # CLIProxyAPI binary (17MB)
│   │       ├── config.yaml      # Server configuration
│   │       ├── AppIcon.icns     # Application icon
│   │       ├── icon-*.png       # Service and status icons
│   │       └── glyph.png        # UI elements
│   ├── Package.swift            # Swift Package Manager config
│   └── Info.plist               # macOS app metadata
├── scripts/
│   └── create-release.sh        # Local release builder
├── .github/workflows/
│   └── release.yml              # Automated release CI/CD
├── Makefile                     # Build automation
├── create-app-bundle.sh         # App bundle creation script
├── entitlements.plist           # macOS entitlements
├── README.md                    # User documentation
├── INSTALLATION.md              # Installation instructions
├── FACTORY_SETUP.md             # Factory CLI integration guide
├── CHANGELOG.md                 # Version history
└── icon.png                     # Repository icon
```

## Architecture

### Design Patterns

1. **Singleton Pattern**: `IconCatalog`, `AuthManager` (ObservableObject)
2. **Observer Pattern**: NotificationCenter for inter-component communication
3. **Factory Pattern**: `AuthCommand` enum encapsulates authentication flows
4. **Proxy Pattern**: Two-tier HTTP proxying architecture
5. **Data Binding**: SwiftUI @Published properties for reactive UI

### Architecture Layers

```
┌─────────────────────────────────────────┐
│         UI Layer (SwiftUI)              │
│    SettingsView, Menu Bar Interface     │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│    AppDelegate (Orchestration)          │
│   Lifecycle, Notifications, Startup     │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Managers Layer                  │
│  ServerManager, ThinkingProxy,          │
│  TunnelManager, AuthManager             │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         System Layer                    │
│  File System, Process Management,       │
│  Network (NWListener)                   │
└─────────────────────────────────────────┘
```

### Network Architecture

```
Client (Factory CLI, etc.)
    ↓ HTTP Request
Port 8317 (ThinkingProxy)
    ↓ Model transformation, thinking parameter injection
Port 8318 (CLIProxyAPI Backend)
    ↓ OAuth token management, API routing
AI Service APIs (Claude, ChatGPT, Gemini, Qwen)
```

## Key Components

### AppDelegate.swift
**Purpose:** Application orchestrator and lifecycle manager

**Key Responsibilities:**
- Menu bar UI setup and management
- Two-stage server startup orchestration
- Status icon updates (active/inactive)
- Notification system integration
- Icon preloading for performance

**Important Methods:**
- `startServer()`: Starts ThinkingProxy (8317), polls for readiness, then starts ServerManager (8318)
- `stopServer()`: Graceful shutdown of both proxy layers
- `pollForProxyReadiness()`: Recursive polling (max 60 attempts @ 50ms intervals)
- `updateMenuBarStatus()`: Syncs menu bar icon with server state

**Startup Sequence:**
1. ThinkingProxy.start() on port 8317
2. Poll until ThinkingProxy.isRunning (up to 3 seconds)
3. ServerManager.start() on port 8318
4. Update UI to reflect running state

### ServerManager.swift
**Purpose:** Backend process manager for CLIProxyAPI

**Key Responsibilities:**
- Manage bundled `cli-proxy-api` binary lifecycle
- Handle OAuth authentication flows for all services
- Maintain circular log buffer (1000 lines max)
- Orphaned process cleanup on startup
- Graceful shutdown with SIGTERM → SIGKILL fallback

**Authentication Commands:**
```swift
enum AuthCommand {
    case claudeLogin      // OAuth browser flow
    case codexLogin       // OAuth browser flow
    case geminiLogin      // OAuth + project selection
    case qwenLogin(email) // Email pre-collection + OAuth
}
```

**Important Details:**
- **RingBuffer**: Circular buffer prevents memory bloat
- **Orphaned Cleanup**: Uses `pgrep cli-proxy-api` + `pkill` on startup
- **Auth Delays**: Gemini (3s auto-submit), Qwen (10s email delay)
- **Graceful Shutdown**: 2-second timeout before force kill

### ThinkingProxy.swift
**Purpose:** HTTP proxy that intercepts and transforms Claude requests with extended thinking parameters

**Key Functionality:**
- Listens on port 8317
- Parses Claude model requests with `-thinking-N` suffix
- Transforms model name and injects thinking parameters
- Forwards modified requests to CLIProxyAPI on port 8318
- Streams responses back to clients

**Transformation Logic:**
```
Input:  model: "claude-sonnet-4-5-20250929-thinking-5000"
Output: model: "claude-sonnet-4-5-20250929"
        thinking: {type: "enabled", budget_tokens: 5000}
        max_tokens: 5512 (budget + headroom)
```

**Token Management:**
- Hard cap: 32,000 tokens (budget capped to 31,999)
- Token headroom: max(1024, budget / 10)
- Adjusts `max_tokens` or `max_output_tokens` to ensure: `max >= budget + headroom`

**Implementation Details:**
- Uses NWListener (modern Network framework)
- Content-Length aware: accumulates chunks until complete body received
- Always uses `Connection: close` (no keep-alive)
- Iterative chunking prevents stack overflow

### SettingsView.swift
**Purpose:** SwiftUI-based settings interface

**Key Features:**
- Server status display with start/stop control
- Authentication UI for 4 services (Claude Code, Codex, Gemini, Qwen)
- Real-time credential monitoring via file system watcher
- Launch-at-login configuration (SMAppService)
- Email pre-collection modal for Qwen

**File System Monitoring:**
- Uses `DispatchSourceFileSystemObject` watching `~/.cli-proxy-api/`
- Detects credential file creation/deletion/modification
- Triggers `AuthManager.checkAuthStatus()` on changes

**Disconnect Workflow:**
1. Stop server if running
2. Find and delete service credential file
3. Restart server with updated credentials
4. Update UI to reflect disconnected state

### AuthStatus.swift
**Purpose:** Authentication state model and manager

**AuthStatus Structure:**
```swift
struct AuthStatus {
    var isAuthenticated: Bool
    var email: String?
    var type: String           // "claude", "codex", "gemini", "qwen"
    var expired: Date?
    var isExpired: Bool        // Computed: expired < Date()
    var statusText: String     // Computed status message
}
```

**AuthManager:**
- Observable object with @Published properties for each service
- `checkAuthStatus()`: Scans `~/.cli-proxy-api/*.json` files
- Parses JSON credentials and ISO8601 expiration dates
- Updates UI reactively when credentials change

### TunnelManager.swift
**Purpose:** Cloudflare tunnel integration for public internet exposure

**Key Features:**
- Detects cloudflared binary in multiple paths
- Launches tunnel with `--url localhost:8317`
- Extracts public URL from stdout/stderr using regex
- 10-second timeout for URL detection
- Installation guidance if cloudflared not found

### IconCatalog.swift
**Purpose:** Thread-safe image caching singleton

**Features:**
- NSLock-based thread safety
- Cache key: name + size + template mode
- Preloading support for performance
- Copy-on-return prevents mutations
- Fallback to system symbols

## Development Workflows

### Building the App

**Quick Development Build:**
```bash
make build          # Debug build
make run            # Build and launch app
make test           # Quick build verification
```

**Release Build:**
```bash
make release        # Release build with optimizations
make app            # Create .app bundle
make install        # Install to /Applications
```

**Manual Build:**
```bash
cd src && swift build -c release
./create-app-bundle.sh
```

### Creating a Release

**Local Release:**
```bash
./scripts/create-release.sh 1.0.7
# Creates: VibeProxy-1.0.7.zip with checksum
```

**GitHub Release (Automated):**
1. Update `CHANGELOG.md` with new version
2. Commit changes: `git commit -m "Release v1.0.7"`
3. Create and push tag: `git tag v1.0.7 && git push origin v1.0.7`
4. GitHub Actions automatically builds, signs, notarizes, and releases

**CI/CD Pipeline (.github/workflows/release.yml):**
1. Triggers on version tags (`v*`)
2. Imports Apple Developer certificates
3. Builds app bundle with version injection
4. Code signs with Developer ID
5. Notarizes with Apple
6. Creates DMG and ZIP archives
7. Calculates SHA-256 checksums
8. Creates GitHub release with artifacts

### Code Signing & Notarization

**Required Secrets (GitHub Actions):**
- `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64`: Developer ID certificate
- `APPLE_DEVELOPER_CERTIFICATE_PASSWORD`: Certificate password
- `APPLE_DEVELOPER_ID_APPLICATION`: Signing identity name
- `APPLE_ID`: Apple ID email
- `APPLE_TEAM_ID`: Developer team ID
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password for notarization

**Local Signing:**
```bash
# Auto-detects Developer ID
./create-app-bundle.sh

# Manual identity specification
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM)" ./create-app-bundle.sh
```

**Verification:**
```bash
codesign --verify --deep --strict --verbose=2 VibeProxy.app
codesign -dv --verbose=4 VibeProxy.app
spctl -a -vvv -t install VibeProxy.app
```

## Important Conventions & Guidelines

### Swift Code Conventions

**Threading:**
- **Main thread**: All UI updates, state mutations in @Published properties
- **Global QoS queues**: Network I/O, process management, file operations
- **Always use `DispatchQueue.main.async`** for UI updates from background threads
- **Weak self**: Use in completion handlers to prevent retain cycles

**Process Management:**
```swift
// ✅ CORRECT: Check if running before waiting
if process.isRunning {
    process.waitUntilExit()
}

// ❌ WRONG: waitUntilExit() blocks forever if already terminated
process.waitUntilExit()

// ✅ CORRECT: Use terminationHandler for async notification
process.terminationHandler = { process in
    // Handle termination
}
```

**Error Handling:**
- User-facing errors: Show NSAlert or user notification
- Silent failures OK for non-critical operations (orphaned cleanup)
- Log all errors with timestamps and severity indicators (✓, ⚠️, ❌)
- Completion handlers should report success state AND diagnostic messages

**State Management:**
- Use `@Published` for observable state
- State changes trigger UI updates automatically
- Post NotificationCenter events for cross-component communication
- File system watcher updates auth state reactively

### Configuration Files

**config.yaml (src/Sources/Resources/config.yaml):**
- Port 8318 (ThinkingProxy uses 8317)
- Auth directory: `~/.cli-proxy-api`
- No API keys required (OAuth-based)
- Disable remote management for security
- Usage statistics enabled by default

**Info.plist (src/Info.plist):**
- Bundle ID: `com.cliproxyapi.menubar`
- Minimum macOS: 13.0 (Ventura)
- LSUIElement: true (menu bar app, no dock icon)
- Version injected from git tags during build

**entitlements.plist:**
- Hardened runtime enabled
- Network client/server entitlements
- File access for bundled resources

### Git Workflow

**Branch Strategy:**
- Development happens on feature branches starting with `claude/`
- Branch naming: `claude/claude-md-<session-id>-<unique-id>`
- Always develop on designated branch (never push to main directly)

**Commit Messages:**
- Use conventional commits format
- Examples:
  - `feat: Add Gemini OAuth support`
  - `fix: Resolve orphaned process cleanup`
  - `docs: Update FACTORY_SETUP.md`
  - `chore: Update dependencies`

**Push Strategy:**
```bash
# Always use -u flag for first push
git push -u origin claude/your-branch-name

# Retry with exponential backoff on network failures (2s, 4s, 8s, 16s)
# Up to 4 retries maximum
```

**Version Tags:**
- Format: `vX.Y.Z` (semantic versioning)
- Triggers automated release workflow
- Version extracted and injected into Info.plist

### File Locations

**Runtime Files:**
- Credentials: `~/.cli-proxy-api/*.json`
- Logs: In-memory circular buffer (1000 lines)
- Config: Bundled in app at `Contents/Resources/config.yaml`

**Bundled Resources:**
- Binary: `Contents/Resources/cli-proxy-api` (17MB)
- Config: `Contents/Resources/config.yaml`
- Icons: `Contents/Resources/icon-*.png`
- App icon: `Contents/Resources/AppIcon.icns`

**Credential File Format:**
```json
{
  "type": "claude",
  "email": "user@example.com",
  "expired": "2025-12-31T23:59:59Z",
  "sessionKey": "...",
  "...": "other service-specific fields"
}
```

## Testing & Quality Assurance

### Manual Testing Checklist

**Server Lifecycle:**
- [ ] App launches successfully
- [ ] Server starts on launch
- [ ] Menu bar icon shows active state (green)
- [ ] Clicking "Stop Server" stops both proxy layers
- [ ] Clicking "Start Server" restarts successfully
- [ ] Orphaned processes cleaned up on restart

**Authentication:**
- [ ] Claude Code: OAuth flow completes, credentials saved
- [ ] Codex: OAuth flow completes, credentials saved
- [ ] Gemini: Project selection auto-submits, credentials saved
- [ ] Qwen: Email pre-collection works, OAuth completes
- [ ] Expiration dates displayed correctly
- [ ] Disconnect removes credentials and restarts server

**Thinking Proxy:**
- [ ] Requests with `-thinking-N` suffix transformed correctly
- [ ] Token budgets calculated properly
- [ ] max_tokens adjusted with proper headroom
- [ ] Invalid suffixes handled gracefully (stripped)
- [ ] Responses streamed correctly
- [ ] Connections closed properly

**UI/UX:**
- [ ] Icons load without lag (preloading works)
- [ ] File monitoring detects credential changes
- [ ] Launch at login toggle works
- [ ] Notifications display correctly
- [ ] Settings window scrolls properly (all services visible)

### Verification Commands

**Check Server Status:**
```bash
lsof -i :8317  # ThinkingProxy
lsof -i :8318  # CLIProxyAPI
```

**Test Thinking Proxy:**
```bash
curl -X POST http://localhost:8317/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-5-20250929-thinking-5000",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 4096
  }'
```

**Check Credentials:**
```bash
ls -la ~/.cli-proxy-api/
cat ~/.cli-proxy-api/claude*.json | jq .
```

**Monitor Logs:**
```bash
# Console.app: Filter for "VibeProxy" or "CLIProxyMenuBar"
log stream --predicate 'process == "CLIProxyMenuBar"' --level debug
```

## Common Issues & Solutions

### "Port already in use" Error
**Cause:** Orphaned cli-proxy-api process from crash
**Solution:**
```bash
pkill -9 cli-proxy-api
# Or restart VibeProxy (auto-cleanup runs on startup)
```

### Authentication Not Detected
**Cause:** File monitor not triggered or credential file format incorrect
**Solution:**
1. Check `~/.cli-proxy-api/` for credential files
2. Verify JSON format matches expected structure
3. Manually refresh: Disconnect and reconnect service

### Code Signing Fails
**Cause:** Missing Developer ID certificate or xattr quarantine
**Solution:**
```bash
# Remove quarantine attributes
xattr -cr src/Sources/Resources/cli-proxy-api
xattr -cr VibeProxy.app

# Verify certificate available
security find-identity -v -p codesigning
```

### Icons Not Loading
**Cause:** Resources not copied correctly during build
**Solution:**
```bash
# Verify resources in bundle
ls -la VibeProxy.app/Contents/Resources/

# Rebuild with clean state
make clean && make app
```

### Thinking Proxy Timeout
**Cause:** CLIProxyAPI not started before accepting connections
**Solution:**
- AppDelegate polls for readiness before starting ServerManager
- Increase polling attempts if needed (currently 60 × 50ms = 3s max)

## Factory CLI Integration

**Purpose:** Use Factory Droids with personal Claude/ChatGPT subscriptions

**Configuration:** `~/.factory/config.json`
```json
{
  "custom_models": [
    {
      "model_display_name": "CC: Sonnet 4.5",
      "model": "claude-sonnet-4-5-20250929",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Sonnet 4.5 (Think)",
      "model": "claude-sonnet-4-5-20250929-thinking-10000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    }
  ]
}
```

**Note:** See `FACTORY_SETUP.md` for complete integration guide.

## Performance Considerations

1. **Icon Preloading:** Icons loaded on app launch to prevent UI lag
2. **Circular Buffer:** Fixed-size log buffer (1000 lines) prevents memory bloat
3. **Iterative Chunking:** Async scheduling prevents stack overflow in proxy
4. **File Monitoring:** Efficient DispatchSource-based monitoring (no polling)
5. **Icon Caching:** Thread-safe cache eliminates redundant disk I/O

## Security Considerations

1. **Localhost Only:** Both proxy layers bind to 127.0.0.1 (no external access)
2. **OAuth Tokens:** Stored in `~/.cli-proxy-api/` with 0600 permissions
3. **HTTPS Upstream:** All AI service communication uses HTTPS
4. **Auto-Refresh:** Tokens refreshed before expiration
5. **Hardened Runtime:** Code signing with hardened runtime enabled
6. **Notarization:** Apple notarization ensures no malware

**Warning:** Using personal subscriptions via proxy may violate ToS. Users assume all risks.

## Resources & References

- **CLIProxyAPI:** https://github.com/router-for-me/CLIProxyAPI
- **Factory CLI:** https://docs.factory.ai/cli
- **Apple Developer:** https://developer.apple.com/documentation/
- **SwiftUI:** https://developer.apple.com/documentation/swiftui
- **Network Framework:** https://developer.apple.com/documentation/network

## Quick Reference

### Key Files to Edit
- **Add feature to UI:** `src/Sources/SettingsView.swift`
- **Modify server lifecycle:** `src/Sources/ServerManager.swift`
- **Change proxy logic:** `src/Sources/ThinkingProxy.swift`
- **Update app metadata:** `src/Info.plist`
- **Add authentication:** `src/Sources/ServerManager.swift` (AuthCommand)
- **Modify icons:** `src/Sources/Resources/icon-*.png`

### Build Commands
```bash
make build     # Debug build
make release   # Release build
make app       # Create .app bundle
make install   # Install to /Applications
make clean     # Clean artifacts
make run       # Build and launch
```

### Version Bumping
1. Update `CHANGELOG.md`
2. Commit changes
3. Create tag: `git tag v1.0.X`
4. Push: `git push origin v1.0.X`
5. GitHub Actions handles rest

### Port Reference
- **8317:** ThinkingProxy (user-facing endpoint)
- **8318:** CLIProxyAPI backend (internal)

---

**Last Updated:** 2025-11-17
**Maintained By:** Automaze, Ltd.
**License:** MIT
