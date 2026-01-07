# VibeProxy for Windows

A Windows port of VibeProxy - an extended thinking proxy for AI coding assistants. This application adds Claude's extended thinking parameters to API requests transparently.

## Running Before the First Release

There is no published Windows release yet. To run VibeProxyWindows, build and run from source:

1. Open PowerShell and download the backend binary:

```powershell
cd VibeProxyWindows
.\download-backend.ps1
```

2. Build and run the app:

```bash
cd VibeProxyWindows
dotnet build
dotnet run
```

## Features

- **System Tray Application**: Runs quietly in the background with easy access
- **Extended Thinking Proxy**: Automatically injects thinking parameters into Claude API requests
- **Multi-Service Authentication**: Connect to Claude, Codex, Copilot, Gemini, Qwen, and Antigravity
- **Real-time Log Viewer**: Monitor proxy activity in the settings window
- **Launch at Login**: Optional auto-start with Windows
- **Dark Theme UI**: Modern, eye-friendly interface

## Requirements

- Windows 10 or later (x64)
- .NET 6.0 Runtime (or use self-contained build)

## Quick Start

### 1. Download Backend Binary

Run the PowerShell script to download the cli-proxy-api backend:

```powershell
cd VibeProxyWindows
.\download-backend.ps1
```

Or manually download from [CLIProxyAPI Releases](https://github.com/router-for-me/CLIProxyAPI/releases) and place `cli-proxy-api.exe` in `VibeProxy/Resources/`.

### 2. Build and Run

```bash
cd VibeProxyWindows
dotnet build
dotnet run
```

### 3. Configure Your AI Tool

Point your AI coding assistant to use the proxy:

```
http://localhost:8317
```

## How It Works

```
Your AI Tool (Cursor, VS Code, etc.)
        │
        ▼
   Port 8317 ──► ThinkingProxy
        │          │
        │          ├── Detects "-thinking-NUMBER" in model name
        │          ├── Strips suffix, injects thinking params
        │          └── Adds anthropic-beta header
        ▼
   Port 8318 ──► cli-proxy-api (backend)
        │
        ▼
   Claude API / Other Providers
```

### Model Name Convention

To enable extended thinking, append `-thinking-BUDGET` to your model name:

| Original Model | With Thinking |
|----------------|---------------|
| `claude-sonnet-4-5-20250929` | `claude-sonnet-4-5-20250929-thinking-10000` |
| `claude-opus-4-5-20250929` | `claude-opus-4-5-20250929-thinking-50000` |

The number represents the thinking budget in tokens.

## Building for Distribution

### Self-Contained Executable (Recommended)

Creates a single EXE file (~150MB) that includes .NET runtime:

```bash
dotnet publish -p:PublishProfile=win-x64-self-contained
```

Output: `bin/Release/publish/win-x64-self-contained/`

### Framework-Dependent

Creates a smaller EXE (~1MB) that requires .NET 6 runtime:

```bash
dotnet publish -p:PublishProfile=win-x64-framework-dependent
```

Output: `bin/Release/publish/win-x64-framework-dependent/`

## Project Structure

```
VibeProxyWindows/
├── VibeProxy.sln              # Solution file
├── download-backend.ps1       # Backend download script
├── convert-icons.ps1          # PNG to ICO converter
├── README.md                  # This file
└── VibeProxy/
    ├── VibeProxy.csproj       # Project file
    ├── App.xaml               # Application entry
    ├── App.xaml.cs            # Main app logic, system tray
    ├── app.manifest           # Windows manifest
    ├── Models/
    │   ├── ServiceType.cs     # Auth service enum
    │   └── AuthAccount.cs     # Account model
    ├── Services/
    │   ├── ServerManager.cs   # Backend process management
    │   ├── ThinkingProxy.cs   # HTTP proxy with thinking injection
    │   └── AuthManager.cs     # Auth file monitoring
    ├── Views/
    │   ├── SettingsWindow.xaml
    │   └── SettingsWindow.xaml.cs
    └── Resources/
        ├── config.yaml        # Backend configuration
        ├── cli-proxy-api.exe  # Backend binary (downloaded)
        ├── icon-active.png    # Tray icon (running)
        ├── icon-inactive.png  # Tray icon (stopped)
        └── icon-*.png         # Service icons
```

## Authentication

Credentials are stored in `~/.cli-proxy-api/` as JSON files:

```
~/.cli-proxy-api/
├── claude_user@email.com.json
├── gemini_user@email.com.json
└── github-copilot_username.json
```

To connect a service:
1. Open Settings (double-click tray icon)
2. Find the service in "Connected Services"
3. Click "Connect"
4. Complete the OAuth flow in your browser

## Troubleshooting

### "Backend binary not found"

Run the download script:
```powershell
.\download-backend.ps1
```

### "Port 8317 already in use"

Another instance of VibeProxy is running, or another application is using port 8317.

### "Failed to start backend server"

Check the logs in the Settings window. Common issues:
- Config file missing
- Backend executable not found
- Port 8318 already in use

### Logs Location

Runtime logs appear in the Settings window. For persistent logs, check:
```
%LOCALAPPDATA%\VibeProxy\logs\
```

## Development

### Prerequisites

- Visual Studio 2022 or VS Code
- .NET 6.0 SDK
- Windows 10 SDK (for WPF)

### Building

```bash
# Debug build
dotnet build

# Release build
dotnet build -c Release

# Run tests (when available)
dotnet test
```

### Converting Icons

If you have ImageMagick installed:
```powershell
.\convert-icons.ps1
```

## License

Same as the main VibeProxy project. See the root LICENSE file.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

For major changes, please open an issue first to discuss what you'd like to change.
