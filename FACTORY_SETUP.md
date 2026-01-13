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
- **Google account** for Antigravity access (provides Gemini 3 Pro models - optional)
- **Google Cloud account** with Gemini API access for Gemini 2.x models (optional)
- **Z.AI API key** for GLM model access (optional) - get one at [z.ai/manage-apikey/apikey-list](https://z.ai/manage-apikey/apikey-list)
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
5. **(Optional)** Click **"Connect"** next to Antigravity
   - Sign in with your Google account
   - Grant permissions for AI model access
   - This provides access to **Gemini 3 Pro** models
   - VibeProxy will automatically save your credentials
6. **(Optional)** Click **"Connect"** next to Gemini
   - Sign in with your Google account
   - Select a Google Cloud project (or accept the default)
   - This provides access to **Gemini 2.x** models
   - VibeProxy will automatically save your credentials
7. **(Optional)** Click **"Add Account"** next to Z.AI GLM
   - Enter your Z.AI API key (get one at [z.ai/manage-apikey/apikey-list](https://z.ai/manage-apikey/apikey-list))
   - This provides access to **GLM-4.7** and other GLM models
   - VibeProxy will securely store your API key

✅ The server starts automatically and runs on port **8317**

## Step 3: Configure Factory CLI

Edit your Factory configuration file at `~/.factory/config.json` (if the file doesn't exist, create it):

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
    },

    {
      "model_display_name": "GLM-4.7",
      "model": "glm-4.7",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GLM-4-Plus",
      "model": "glm-4-plus",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GLM-4-Air",
      "model": "glm-4-air",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model_display_name": "GLM-4-Flash",
      "model": "glm-4-flash",
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
   - `claude-opus-4-5` (Claude Opus 4.5 - Most powerful)
   - `claude-sonnet-4-5` (Claude 4.5 Sonnet)
   - `gpt-5.1`, `gpt-5.1-codex`, etc.
   - `gemini-3-pro-preview`, `gemini-3-pro-image-preview`, `gemini-2.5-pro`, etc.

3. **Start coding!** Factory will now route all requests through VibeProxy, which handles authentication automatically.

## Available Models

### Claude Models
- `claude-opus-4-5-20251101` - Claude Opus 4.5 (Most powerful, latest)
- `claude-sonnet-4-5-20250929` - Claude 4.5 Sonnet
- **Extended Thinking Variants** (Claude 3.7+, Opus 4/4.5, Sonnet 4):
  - `*-thinking-NUMBER` - Custom thinking token budget (e.g., `-thinking-5000`)
  - Recommended presets:
    - `*-thinking-4000` - "Think" mode (~4K tokens)
    - `*-thinking-10000` - "Think harder" mode (~10K tokens)
    - `*-thinking-32000` - "Ultra think" mode (~32K tokens)

### Gemini Models

### Claude Models via Antigravity

Antigravity provides access to Claude models with a generous usage quota (shared with Sonnet and GPT-OSS). These models are accessed via the OpenAI-compatible API format and require **Antigravity** authentication.

**Available Models:**
- `gemini-claude-opus-4-5-thinking` - Claude Opus 4.5 with extended thinking (backend-controlled budget)
- `gemini-claude-sonnet-4-5-thinking` - Claude Sonnet 4.5 with extended thinking (backend-controlled budget)
- `gemini-claude-sonnet-4-5` - Claude Sonnet 4.5 (no thinking)

> [!TIP]
> See the [Step 3 configuration example](#step-3-configure-factory-cli) above for the full Factory CLI config including these models.

**Gemini 3 Pro** (via Antigravity - requires Antigravity authentication):
- `gemini-3-pro-preview` - Gemini 3 Pro (Latest preview model)
- `gemini-3-pro-image-preview` - Gemini 3 Pro with enhanced vision capabilities

**Gemini 2.x** (via Gemini CLI - requires Gemini authentication):
- `gemini-2.5-pro` - Gemini 2.5 Pro (Most capable production model)
- `gemini-2.5-flash` - Gemini 2.5 Flash (Fast and efficient)
- `gemini-2.5-flash-lite` - Gemini 2.5 Flash Lite (Lightweight and fastest)

> [!IMPORTANT]
> **Gemini 3 Pro Configuration Requirements**:
> - **Authentication**: Gemini 3 Pro models require **Antigravity** authentication (not Gemini CLI auth)
> - **Provider Setting**: Must use `"provider": "openai"` in Factory config (Antigravity uses OpenAI API format)
> - **Available in**: VibeProxy v1.0.9+ with CLIProxyAPI 6.5.1+
> 
> Connect to Antigravity in VibeProxy Settings → Click "Connect" next to Antigravity → Sign in with your Google account. After connecting, restart VibeProxy to activate Gemini 3 Pro access.

### Qwen Models
- `qwen3-coder-plus` - Qwen3 Coder Plus (Most capable coding model)
- `qwen3-coder-flash` - Qwen3 Coder Flash (Fast coding assistant)

### Z.AI GLM Models
- `glm-4.7` - GLM-4.7 (Latest and most capable GLM model)
- `glm-4-plus` - GLM-4-Plus (Enhanced GLM model)
- `glm-4-air` - GLM-4-Air (Balanced performance)
- `glm-4-flash` - GLM-4-Flash (Fast and efficient)

> [!NOTE]
> Z.AI GLM models require an API key instead of OAuth authentication. Get your API key at [z.ai/manage-apikey/apikey-list](https://z.ai/manage-apikey/apikey-list) and add it in VibeProxy Settings → Z.AI GLM → Add Account.

### OpenAI Models

**GPT-5.2** (Latest):
- `gpt-5.2` - Latest GPT with improved reasoning
- `gpt-5.2-codex` - Latest Codex for coding tasks

**GPT-5.1**:
- `gpt-5.1` - Next-gen GPT with better reasoning + planning
- `gpt-5.1-codex` - Codex upgrade (faster reasoning + better tool use)
- `gpt-5.1-codex-max` - Codex Max optimized for long-horizon agentic coding tasks

**Reasoning Effort Control** (GPT-5.1+):

Use parentheses syntax to control reasoning effort:
- `gpt-5.2(none)` - No extended reasoning
- `gpt-5.2(low)` - Low reasoning effort
- `gpt-5.2(medium)` - Medium reasoning effort
- `gpt-5.2(high)` - High reasoning effort
- `gpt-5.2(xhigh)` - Extra high reasoning effort

This works with any GPT-5.x model: `gpt-5.1(high)`, `gpt-5.1-codex(medium)`, `gpt-5.2-codex(high)`, etc.

No manual CLIProxyAPI update is required—VibeProxy automatically keeps CLIProxyAPI up to date via our new auto-update workflow, so you can use new models immediately.

## Troubleshooting

### VibeProxy Menu Bar Status
- **Green dot**: Server is running
- **Red dot**: Server is stopped
- **Click the status** to toggle the server on/off

### Connection Issues

| Problem | Solution |
|---------|----------|
| Can't connect to Claude/Codex/Gemini | Re-click "Connect" in VibeProxy settings |
| Factory shows 404 errors | Make sure VibeProxy server is running (check menu bar) |
| Authentication expired | Disconnect and reconnect the service in VibeProxy |
| Port 8317 already in use | Quit any other instances of VibeProxy or CLIProxyAPI |
| Gemini returns 401 errors | Verify your Google Cloud project has Gemini API enabled |

### Verification Checklist

1. ✅ VibeProxy is running (menu bar icon shows green)
2. ✅ Services (Claude, Codex, and optionally Gemini) show as "Connected" in settings
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
- Claude Opus 4.5 (`claude-opus-4-5-*`)
- Claude Sonnet 4.5 (`claude-sonnet-4-5-*`)

This works seamlessly with Factory CLI - just select the thinking variant in your model selector!

### Interleaved Thinking (Automatic)

When you use extended thinking (`-thinking-*` suffix), VibeProxy automatically enables **interleaved thinking** by adding the `anthropic-beta: interleaved-thinking-2025-05-14` header to your requests.

**What is Interleaved Thinking?**

Without interleaved thinking, Claude thinks once at the beginning and then executes all tool calls. With interleaved thinking enabled, Claude can think *between* tool calls, allowing it to:

- **Reason about tool results** before deciding what to do next
- **Chain multiple tool calls** with reasoning steps in between
- **Make more nuanced decisions** based on intermediate results
- **Adapt its approach** as it learns more from each tool interaction

**Why This Matters for Coding Agents**

AI coding tools like Factory Droids heavily rely on tool use (reading files, searching code, running commands). Interleaved thinking significantly improves the quality of multi-step coding tasks because Claude can:

1. Read a file → *think about what it found* → decide which file to read next
2. Run a test → *analyze the failure* → make a targeted fix
3. Search for a pattern → *reason about the results* → refine the search

**Automatic Enablement**

You don't need to configure anything - when you use any `-thinking-*` model variant, VibeProxy automatically:
1. Adds the thinking parameter to the request body
2. Injects the `anthropic-beta: interleaved-thinking-2025-05-14` header
3. Merges with any existing beta headers (no duplicates)

This is enabled by default because if you're opting into extended thinking, you almost certainly want the improved reasoning that interleaved thinking provides for tool-heavy workflows.

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
