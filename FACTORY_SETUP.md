# Using Factory AI with VibeProxy

A simplified guide for using Factory CLI (Droid) with your personal Claude and ChatGPT subscriptions through VibeProxy.

## What is This?

This guide shows you how to use [Factory CLI](https://app.factory.ai/r/FM8BJHFQ) with your personal Claude Code Pro/Max and ChatGPT Plus/Pro subscriptions instead of paying for separate API access. VibeProxy acts as a bridge that handles authentication and routing automatically.

**How it works:**

```
Factory CLI  →  VibeProxy  →  [OAuth Authentication]  →  Claude / ChatGPT APIs
```

VibeProxy manages OAuth tokens, auto-refreshes them, routes requests, and handles API format conversion — all automatically in the background.

## Prerequisites

- macOS 13.0+ (Ventura or later)
- Active **Claude Code Pro/Max** subscription for Anthropic access
- Active **ChatGPT Plus/Pro** subscription for OpenAI Codex access
- Factory CLI installed: `curl -fsSL https://app.factory.ai/cli | sh`

## Step 1: Install VibeProxy

1. **Download [VibeProxy.app](https://github.com/automazeio/vibeproxy/releases)** from the releases page or build from source
2. **Install**: Drag `VibeProxy.app` to your `/Applications` folder
3. **Launch**: Open VibeProxy from Applications
   - If macOS blocks it: Right-click → Open, then click "Open" in the dialog

## Step 2: Connect Your Accounts

Once VibeProxy is running:

1. Click the **VibeProxy menu bar icon**
2. Select **"Open Settings"**
3. Click **"Connect"** next to Claude Code
   - Your browser will open for authentication
   - Complete the login process
   - VibeProxy will automatically detect when you're authenticated
4. Click **"Connect"** next to Codex
   - Follow the same browser authentication process
   - Wait for VibeProxy to confirm the connection

✅ The server starts automatically and runs on port **8317**

## Step 3: Configure Factory CLI

Edit your Factory configuration file at `~/.factory/config.json` (if the file doesn't exist, create it):

```json
{
  "custom_models": [
    {
      "model_display_name": "CC: Opus 4.1",
      "model": "claude-opus-4-1-20250805",
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
      "model_display_name": "CC: Sonnet 4.5 (Think)",
      "model": "claude-sonnet-4-5-20250929-thinking-4000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Sonnet 4.5 (Think Harder)",
      "model": "claude-sonnet-4-5-20250929-thinking-10000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model_display_name": "CC: Sonnet 4.5 (Ultra Think)",
      "model": "claude-sonnet-4-5-20250929-thinking-32000",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },

    {
      "model_display_name": "GPT-5 Codex",
      "model": "gpt-5-codex",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5 Codex (Low)",
      "model": "gpt-5-codex-low",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5 Codex (Medium)",
      "model": "gpt-5-codex-medium",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5 Codex (High)",
      "model": "gpt-5-codex-high",
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
      "model_display_name": "GPT-5.1 Codex (Low)",
      "model": "gpt-5.1-codex-low",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 Codex (Medium)",
      "model": "gpt-5.1-codex-medium",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 Codex (High)",
      "model": "gpt-5.1-codex-high",
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
      "model_display_name": "GPT-5.1 (Minimal)",
      "model": "gpt-5.1-minimal",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 (Low)",
      "model": "gpt-5.1-low",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 (Medium)",
      "model": "gpt-5.1-medium",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5.1 (High)",
      "model": "gpt-5.1-high",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5",
      "model": "gpt-5",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5 (Minimal)",
      "model": "gpt-5-minimal",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5 (Low)",
      "model": "gpt-5-low",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5 (Medium)",
      "model": "gpt-5-medium",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GPT-5 (High)",
      "model": "gpt-5-high",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    }
  ]
}
```

## Step 4: Use Factory CLI

1. **Launch Factory CLI**:
   ```bash
   droid
   ```

2. **Select your model**:
   ```
   /model
   ```
   Then choose from:
   - `claude-sonnet-4-5-20250929` (Claude 4.5 Sonnet)
   - `claude-opus-4-1-20250805`
   - `gpt-5`, `gpt-5.1`, `gpt-5-codex`, `gpt-5.1-codex`, etc.

3. **Start coding!** Factory will now route all requests through VibeProxy, which handles authentication automatically.

## Available Models

### Claude Models
- `claude-opus-4-1-20250805` - Claude Opus 4.1 (Most powerful)
- `claude-sonnet-4-5-20250929` - Claude 4.5 Sonnet (Latest)
- **Extended Thinking Variants** (Claude 3.7+, Opus 4, Sonnet 4):
  - `*-thinking-NUMBER` - Custom thinking token budget (e.g., `-thinking-5000`)
  - Recommended presets:
    - `*-thinking-4000` - "Think" mode (~4K tokens)
    - `*-thinking-10000` - "Think harder" mode (~10K tokens)
    - `*-thinking-32000` - "Ultra think" mode (~32K tokens)

### OpenAI Models
- `gpt-5` - Standard GPT-5
- `gpt-5-minimal` / `low` / `medium` / `high` - Different reasoning effort levels
- `gpt-5-codex` - Optimized for coding
- `gpt-5-codex-low` / `medium` / `high` - Codex with different reasoning levels
- `gpt-5.1` - Next-gen GPT with better reasoning + planning
- `gpt-5.1-minimal` / `low` / `medium` / `high` - GPT-5.1 with explicit reasoning effort controls
- `gpt-5.1-codex` - Latest Codex upgrade (faster reasoning + better tool use)
- `gpt-5.1-codex-low` / `medium` / `high` - Same model with explicit reasoning effort presets

### Upgrading to GPT-5.1 / GPT-5.1 Codex

1. **Update your Factory config**: Add the `"gpt-5.1*"` and `"gpt-5.1-codex*"` blocks from the sample above to `~/.factory/config.json` (keep the GPT-5 entries if teammates still rely on them).
2. **Reload Factory CLI**: Quit and relaunch `droid`, then run `/model` to refresh the picker. The new GPT-5.1 + GPT-5.1 Codex variants will now appear.
3. **Pick the right preset**:  
   - `gpt-5.1` / `gpt-5.1-codex` → balanced reasoning  
   - `gpt-5.1-minimal` / `-codex-low` → cheapest + minimal chain-of-thought  
   - `gpt-5.1-medium` / `-codex-medium` → default for day-to-day coding  
   - `gpt-5.1-high` / `-codex-high` → max reasoning depth (pairs well with Factory’s “Fix Tests” + “Write Spec” droids)
4. **Sanity-check**: Ask Factory to run `/model`; it will echo your active model so you can confirm the correct GPT-5.1 variant before starting a run.

No manual CLIProxyAPI update is required—VibeProxy automatically keeps CLIProxyAPI up to date via our new auto-update workflow, so you can use new models immediately.

## Troubleshooting

### VibeProxy Menu Bar Status
- **Green dot**: Server is running
- **Red dot**: Server is stopped
- **Click the status** to toggle the server on/off

### Connection Issues

| Problem | Solution |
|---------|----------|
| Can't connect to Claude/Codex | Re-click "Connect" in VibeProxy settings |
| Factory shows 404 errors | Make sure VibeProxy server is running (check menu bar) |
| Authentication expired | Disconnect and reconnect the service in VibeProxy |
| Port 8317 already in use | Quit any other instances of VibeProxy or CLIProxyAPI |

### Verification Checklist

1. ✅ VibeProxy is running (menu bar icon shows green)
2. ✅ Both Claude and Codex show as "Connected" in settings
3. ✅ Factory CLI config has the custom models configured
4. ✅ `droid` can select your custom models
5. ✅ Test with a simple prompt: "what day is it?"

## Extended Thinking Mode

> [!NOTE]
> The `-thinking-NUMBER` model naming convention is a **VibeProxy-specific implementation**, not an official Claude model name from Anthropic. VibeProxy intercepts these custom model names and translates them into proper API calls with the `thinking` parameter.

VibeProxy automatically adds extended thinking support for Claude models! Simply append a thinking suffix to any Claude model name:

**Model Name Pattern**: `{model-name}-thinking-{NUMBER}`

**Recommended Presets** (based on Anthropic's official guidelines):
- `claude-sonnet-4-5-20250929-thinking-4000` → **"Think"** (~4K tokens)
- `claude-sonnet-4-5-20250929-thinking-10000` → **"Think harder"** (~10K tokens)
- `claude-sonnet-4-5-20250929-thinking-32000` → **"Ultra think"** (~32K tokens)

**Custom Budgets**:
You can specify any token budget number:
- `claude-sonnet-4-5-20250929-thinking-2000` → 2,000 tokens
- `claude-sonnet-4-5-20250929-thinking-16000` → 16,000 tokens
- `claude-sonnet-4-5-20250929-thinking-50000` → 50,000 tokens

**How It Works**:
1. VibeProxy's thinking proxy intercepts requests on port 8317
2. Recognizes the `-thinking-{NUMBER}` suffix
3. Strips the suffix from the model name
4. Adds the `thinking` parameter with the specified budget
5. Forwards the modified request to CLIProxyAPI

**Invalid Suffix Handling**:
If the suffix is not a valid integer (e.g., `-thinking-blabla`), VibeProxy strips the suffix and uses the vanilla model without thinking.

**What You'll See**:
- Claude's step-by-step reasoning process before the final answer
- More detailed analysis for complex problems
- Transparent thought process in the response

**Supported Models**:
- Claude 3.7 Sonnet (`claude-3-7-sonnet-20250219`)
- Claude Opus 4 (`claude-opus-4-*`)
- Claude Sonnet 4 (`claude-sonnet-4-*`)

This works seamlessly with Factory CLI - just select the thinking variant in your model selector!

## Tips

- **Launch at Login**: Enable in VibeProxy settings to auto-start the server
- **Auth Folder**: Click "Open Folder" in settings to view authentication tokens
- **Server Control**: VibeProxy automatically stops the server and releases port 8317 when you quit

## Security

- All authentication tokens are stored locally in `~/.cli-proxy-api/`
- Token files are secured with proper permissions (0600)
- VibeProxy only binds to localhost (127.0.0.1)
- All upstream traffic uses HTTPS
- Tokens are auto-refreshed before expiration

---

> [!WARNING]
> <br>**By using this VibeProxy, you acknowledge and accept the following:**
>
> - **Terms of Service Risk**: This approach may violate the Terms of Service of AI model providers (Anthropic, OpenAI, etc.). You are solely responsible for ensuring compliance with all applicable terms and policies.
>
> - **Account Risk**: Model providers may detect this usage pattern and take punitive action, including but not limited to account suspension, permanent ban, or loss of access to paid subscriptions.
>
> - **No Guarantees**: Providers may change their APIs, authentication mechanisms, or policies at any time, rendering this method inoperable without notice.
>
> - **Assumption of Risk**: By proceeding, you assume all legal, financial, and technical risks. The authors and contributors of this guide and CLIProxyAPI bear no responsibility for any consequences arising from your use of this method.
>
> **Use at your own risk. Proceed only if you understand and accept these risks.**

---

## Acknowledgments

VibeProxy is built on top of [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), an excellent unified proxy server for AI services. Without CLIProxyAPI's robust OAuth handling, token management, and API routing capabilities, this application would not be possible.

**Special thanks to the CLIProxyAPI project and its contributors for creating the foundation that makes VibeProxy work.**

## References

- **CLIProxyAPI**: [https://github.com/router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
- **Factory CLI**: [https://docs.factory.ai/cli](https://docs.factory.ai/cli)
- **Original Setup Guide**: [https://gist.github.com/ben-vargas/9f1a14ac5f78d10eba56be437b7c76e5](https://gist.github.com/ben-vargas/9f1a14ac5f78d10eba56be437b7c76e5)

---

**Need Help?**
- Report issues: [GitHub Issues](https://github.com/automazeio/vibeproxy/issues)
- VibeProxy by [Automaze, Ltd.](https://automaze.io)
