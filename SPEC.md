# VibeProxy — Technical Specification

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                 SwiftUI App (macOS)                  │
│          Menu Bar Item + Settings Window              │
├──────────┬──────────┬───────────────────────────────┤
│AppDelegate│Server   │ SettingsView                  │
│menu bar  │Manager  │ SwiftUI controls              │
│lifecycle │process  │ provider toggles              │
│          │control  │ auth status                   │
├──────────┴─────────┴───────────────────────────────┤
│              AuthStatus Monitor                      │
│     ~/.cli-proxy-api/ file watching                 │
├─────────────────────────────────────────────────────┤
│            CLIProxyAPIPlus (binary)                  │
│       OAuth proxy + API routing engine               │
├────────┬────────┬────────┬────────┬────────────────┤
│Claude  │ Codex  │Gemini  │Qwen    │Antigravity/Z.AI│
│OAuth   │ OAuth  │OAuth   │OAuth   │API key         │
└────────┴────────┴────────┴────────┴────────────────┘
```

## Components

| Component | File | Responsibility |
|-----------|------|---------------|
| AppDelegate | `Sources/AppDelegate.swift` | Menu bar item, window lifecycle |
| ServerManager | `Sources/ServerManager.swift` | Server process, OAuth auth |
| SettingsView | `Sources/SettingsView.swift` | Main SwiftUI interface |
| AuthStatus | `Sources/AuthStatus.swift` | Auth file monitoring |
| main | `Sources/main.swift` | App entry point |
| Config | `Resources/config.yaml` | CLIProxyAPIPlus configuration |

## Provider Support

| Provider | Auth Type | Models | Multi-Account |
|----------|-----------|--------|---------------|
| Claude Code | OAuth | Sonnet 4.5, Opus 4.5 | Yes (round-robin) |
| Codex | OAuth | GPT-5.1, GPT-5.1 Codex | Yes |
| Gemini | OAuth | Gemini 3 Pro | Yes |
| Qwen | OAuth | Qwen models | Yes |
| Antigravity | OAuth | Gemini 3 Pro | Yes |
| Z.AI GLM | API key | GLM-4.7 | Yes |

## Data Flow

```
Factory Droids / Amp CLI
        │
        ▼
   localhost:PORT
        │
        ▼
  VibeProxy (CLIProxyAPIPlus)
   ┌────┴────┐
   │ Provider │ ← round-robin + failover
   │ Selection│
   └────┬────┘
        │
        ▼
  AI Provider APIs
```

## Configuration

```yaml
# config.yaml (bundled)
providers:
  claude:
    enabled: true
    oauth_path: "~/.cli-proxy-api/claude/"
    vercel_gateway: false
  codex:
    enabled: true
    oauth_path: "~/.cli-proxy-api/codex/"
  gemini:
    enabled: true
    oauth_path: "~/.cli-proxy-api/gemini/"

server:
  port: 0  # auto-select
  host: "127.0.0.1"

multi_account:
  strategy: "round_robin"
  failover: true
```

## Performance Targets

| Metric | Target |
|--------|--------|
| App launch | <1s |
| Server start | <3s |
| Auth detection | <500ms (file watch) |
| Request proxy overhead | <10ms |
| Memory footprint | <50MB |
| CPU idle | <1% |
| Update check | Once daily (Sparkle) |

## Security Model

- No secrets stored in app bundle
- OAuth tokens in `~/.cli-proxy-api/` (user-only permissions)
- Vercel AI Gateway option to avoid direct OAuth token exposure
- Code signed + notarized (no Gatekeeper warnings)
- Self-contained .app (no external dependencies)
