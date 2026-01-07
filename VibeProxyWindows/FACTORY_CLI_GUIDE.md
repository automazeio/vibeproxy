# Using Factory AI with VibeProxy on Windows

A simplified guide for using Factory CLI (Droid) with your personal Claude and ChatGPT subscriptions through VibeProxy on Windows.

## What is This?

This guide shows you how to use [Factory CLI](https://app.factory.ai/r/FM8BJHFQ) with your personal Claude Code Pro/Max and ChatGPT Plus/Pro subscriptions instead of paying for separate API access. VibeProxy acts as a bridge that handles authentication and routing automatically.

**How it works:**

```
Factory CLI  →  VibeProxy  →  [OAuth Authentication]  →  Claude / ChatGPT APIs
```

VibeProxy manages OAuth tokens, auto-refreshes them, routes requests, and handles API format conversion — all automatically in the background.

## Prerequisites

- Windows 10 or later (x64)
- .NET 6.0 Runtime (or use self-contained build)
- Active **Claude Code Pro/Max** subscription for Anthropic access
- Active **ChatGPT Plus/Pro** subscription for OpenAI Codex access
- **Google account** for Antigravity access (provides Gemini 3 Pro models - optional)
- **Google Cloud account** with Gemini API access for Gemini 2.x models (optional)
- Factory CLI installed (see [Factory CLI docs](https://docs.factory.ai/cli))

## Step 1: Install VibeProxy for Windows

### Option A: Build from Source

1. **Clone the repository**:
   ```powershell
   git clone https://github.com/automazeio/vibeproxy.git
   cd vibeproxy\VibeProxyWindows
   ```

2. **Ensure you have the backend binary**:
   - Download `cli-proxy-api-plus.exe` from [CLIProxyAPI Releases](https://github.com/router-for-me/CLIProxyAPI/releases)
   - Place it in `VibeProxy\Resources\cli-proxy-api-plus.exe`

3. **Build and run**:
   ```powershell
   cd VibeProxy
   dotnet build
   dotnet run
   ```

### Option B: Use Published Release

```powershell
# Self-contained build (includes .NET runtime, ~150MB)
dotnet publish -p:PublishProfile=win-x64-self-contained

# Or framework-dependent build (requires .NET 6 runtime, ~1MB)
dotnet publish -p:PublishProfile=win-x64-framework-dependent
```

The executable will be in `bin\Release\publish\win-x64-self-contained\` or `bin\Release\publish\win-x64-framework-dependent\`.

## Step 2: Connect Your Accounts

Once VibeProxy is running (look for the icon in the system tray near the clock):

1. **Double-click the VibeProxy system tray icon** to open Settings
2. Click **"Connect"** next to Claude Code
   - Your browser will open for authentication
   - Complete the login process
   - VibeProxy will automatically detect when you're authenticated
3. Click **"Connect"** next to Codex
   - Follow the same browser authentication process
   - Wait for VibeProxy to confirm the connection
4. **(Optional)** Click **"Connect"** next to Antigravity
   - Sign in with your Google account
   - Grant permissions for AI model access
   - This provides access to **Gemini 3 Pro** models
5. **(Optional)** Click **"Connect"** next to Gemini
   - Sign in with your Google account
   - Select a Google Cloud project (or accept the default)
   - This provides access to **Gemini 2.x** models

✅ The server starts automatically and runs on port **8317**

## Step 3: Configure Factory CLI

Edit your Factory configuration file at `%USERPROFILE%\.factory\config.json`:

```powershell
# Create directory if it doesn't exist
mkdir "$env:USERPROFILE\.factory" -Force

# Open config file in notepad
notepad "$env:USERPROFILE\.factory\config.json"
```

Add the following configuration:

```json
{
  "custom_models": [
    {
      "model_display_name": "CC: Opus 4.5 (High)",
      "model": "claude-opus-4-5-20251101-thinking-32000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Opus 4.5 (Medium)",
      "model": "claude-opus-4-5-20251101-thinking-10000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Opus 4.5 (Low)",
      "model": "claude-opus-4-5-20251101-thinking-4000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Opus 4.5",
      "model": "claude-opus-4-5-20251101",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Sonnet 4.5",
      "model": "claude-sonnet-4-5-20250929",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Sonnet 4.5 (Low)",
      "model": "claude-sonnet-4-5-20250929-thinking-4000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Sonnet 4.5 (Medium)",
      "model": "claude-sonnet-4-5-20250929-thinking-10000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Sonnet 4.5 (High)",
      "model": "claude-sonnet-4-5-20250929-thinking-32000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "AG: Opus 4.5 Thinking",
      "model": "gemini-claude-opus-4-5-thinking",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "AG: Sonnet 4.5 Thinking",
      "model": "gemini-claude-sonnet-4-5-thinking",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "AG: Sonnet 4.5",
      "model": "gemini-claude-sonnet-4-5",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 Codex",
      "model": "gpt-5.1-codex",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 Codex (High)",
      "model": "gpt-5.1-codex(high)",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 Codex Max",
      "model": "gpt-5.1-codex-max",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1",
      "model": "gpt-5.1",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 (Low)",
      "model": "gpt-5.1(low)",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 (High)",
      "model": "gpt-5.1(high)",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.2",
      "model": "gpt-5.2",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.2 (High)",
      "model": "gpt-5.2(high)",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.2 Codex",
      "model": "gpt-5.2-codex",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.2 Codex (High)",
      "model": "gpt-5.2-codex(high)",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "Gemini 3 Pro",
      "model": "gemini-3-pro-preview",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "Gemini 3 Pro (Image)",
      "model": "gemini-3-pro-image-preview",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "Gemini 2.5 Pro",
      "model": "gemini-2.5-pro",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "Gemini 2.5 Flash",
      "model": "gemini-2.5-flash",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "Gemini 2.5 Flash Lite",
      "model": "gemini-2.5-flash-lite",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "Qwen3 Coder Plus",
      "model": "qwen3-coder-plus",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "Qwen3 Coder Flash",
      "model": "qwen3-coder-flash",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    }
  ]
}
```

## Step 4: Use Factory CLI

1. **Launch Factory CLI**:
   ```powershell
   droid
   ```

2. **Select your model**:
   ```
   /model
   ```
   Then choose from your configured models.

3. **Start coding!** Factory will now route all requests through VibeProxy.

## Available Models

### Claude Models (via Claude Code subscription)
- `claude-opus-4-5-20251101` - Claude Opus 4.5 (Most powerful, latest)
- `claude-sonnet-4-5-20250929` - Claude 4.5 Sonnet

**Extended Thinking Variants**:
- `*-thinking-4000` - "Think" mode (~4K tokens)
- `*-thinking-10000` - "Think harder" mode (~10K tokens)
- `*-thinking-32000` - "Ultra think" mode (~32K tokens)

### Claude Models via Antigravity
- `gemini-claude-opus-4-5-thinking` - Claude Opus 4.5 with extended thinking
- `gemini-claude-sonnet-4-5-thinking` - Claude Sonnet 4.5 with extended thinking
- `gemini-claude-sonnet-4-5` - Claude Sonnet 4.5 (no thinking)

### Gemini Models

**Gemini 3 Pro** (via Antigravity):
- `gemini-3-pro-preview` - Gemini 3 Pro
- `gemini-3-pro-image-preview` - Gemini 3 Pro with enhanced vision

**Gemini 2.x** (via Gemini CLI):
- `gemini-2.5-pro` - Gemini 2.5 Pro
- `gemini-2.5-flash` - Gemini 2.5 Flash
- `gemini-2.5-flash-lite` - Gemini 2.5 Flash Lite

### OpenAI Models (via Codex subscription)

**GPT-5.2** (Latest):
- `gpt-5.2`, `gpt-5.2-codex`

**GPT-5.1**:
- `gpt-5.1`, `gpt-5.1-codex`, `gpt-5.1-codex-max`

**Reasoning Effort Control**:
- `gpt-5.2(low)`, `gpt-5.2(medium)`, `gpt-5.2(high)`, `gpt-5.2(xhigh)`

### Qwen Models
- `qwen3-coder-plus` - Qwen3 Coder Plus
- `qwen3-coder-flash` - Qwen3 Coder Flash

## Troubleshooting

### VibeProxy System Tray Status
- **Green icon**: Server is running
- **Red icon**: Server is stopped
- **Right-click** the icon for options (Start/Stop, Settings, Quit)

### Common Issues

| Problem | Solution |
|---------|----------|
| "VibeProxy is already running" | Check system tray for existing instance |
| Can't connect to services | Re-click "Connect" in VibeProxy settings |
| Factory shows 404 errors | Make sure VibeProxy is running (check system tray) |
| Authentication expired | Disconnect and reconnect the service |
| Port 8317 in use | Close other VibeProxy instances or apps using the port |
| Backend binary not found | Place `cli-proxy-api-plus.exe` in Resources folder |

### Verification Checklist

1. ✅ VibeProxy is running (system tray icon is green)
2. ✅ Services show as "Connected" in settings (green dots)
3. ✅ Factory CLI config has the custom models at `%USERPROFILE%\.factory\config.json`
4. ✅ `droid` can select your custom models with `/model`
5. ✅ Test with a simple prompt: "what day is it?"

## Windows-Specific Notes

### Authentication Token Location

Tokens are stored in:
```
%USERPROFILE%\.cli-proxy-api\
```

Example:
```
C:\Users\YourName\.cli-proxy-api\
├── claude_user@email.com.json
├── codex_username.json
└── gemini_user@email.com.json
```

### Launch at Login

Enable in VibeProxy settings to auto-start with Windows. This adds a registry entry to:
```
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
```

### Firewall

If Windows Firewall prompts you, allow VibeProxy on **Private networks** only (it only binds to localhost).

### Running from Command Line

```powershell
# From source
cd VibeProxyWindows\VibeProxy
dotnet run

# Or run the built executable
.\bin\Release\net6.0-windows\VibeProxy.exe
```

## Extended Thinking Mode

> **Note**: The `-thinking-NUMBER` model naming convention is a **VibeProxy-specific implementation**.

Append a thinking suffix to any Claude model name:

**Pattern**: `{model-name}-thinking-{NUMBER}`

**Examples**:
- `claude-sonnet-4-5-20250929-thinking-4000` → 4K token budget
- `claude-opus-4-5-20251101-thinking-32000` → 32K token budget

### Interleaved Thinking (Automatic)

When using extended thinking, VibeProxy automatically enables **interleaved thinking** which allows Claude to think between tool calls, improving multi-step coding tasks.

## Security

- All tokens stored locally in `%USERPROFILE%\.cli-proxy-api\`
- VibeProxy only binds to localhost (127.0.0.1)
- All upstream traffic uses HTTPS
- Tokens auto-refresh before expiration
- Single-instance enforcement prevents multiple copies running

## Tips

- **Quick Access**: Double-click the system tray icon to open Settings
- **Copy Server URL**: Right-click tray icon → "Copy Server URL" (when running)
- **View Logs**: Open Settings to see real-time server logs
- **Auth Folder**: Click "Open Auth Folder" in Settings to view tokens

---

> [!WARNING]
> **By using VibeProxy, you acknowledge and accept:**
>
> - **Terms of Service Risk**: This approach may violate ToS of AI providers
> - **Account Risk**: Providers may suspend accounts for this usage pattern
> - **No Guarantees**: APIs may change without notice
>
> **Use at your own risk.**

---

## References

- **VibeProxy**: [https://github.com/automazeio/vibeproxy](https://github.com/automazeio/vibeproxy)
- **CLIProxyAPI**: [https://github.com/router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
- **Factory CLI**: [https://docs.factory.ai/cli](https://docs.factory.ai/cli)

---

**Need Help?**
- Report issues: [GitHub Issues](https://github.com/automazeio/vibeproxy/issues)
- VibeProxy by [Automaze, Ltd.](https://automaze.io)
