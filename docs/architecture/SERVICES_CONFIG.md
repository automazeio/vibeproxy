# VibeProxy Services Configuration

This document describes the configuration entries for each service available in VibeProxy.

## Services Overview

### 1. Claude Code
**Provider**: Anthropic  
**Config Section**: `claude-api-key`

```yaml
claude-api-key:
  - api-key: "sk-ant-..."
    base-url: "https://api.anthropic.com"  # optional
    headers:
      X-Custom-Header: "value"  # optional
    proxy-url: "socks5://proxy:1080"  # optional
    models:
      - name: "claude-3-5-sonnet-20241022"
        alias: "claude-sonnet"
```

**Available Models**:
- `claude-3-5-sonnet-20241022` - Claude 3.5 Sonnet (Latest, fast)
- `claude-3-5-haiku-20241022` - Claude 3.5 Haiku (Compact)
- `claude-3-opus-20250219` - Claude 3 Opus (Most capable)

---

### 2. Codex (OpenAI)
**Provider**: OpenAI  
**Config Section**: `codex-api-key`

```yaml
codex-api-key:
  - api-key: "sk-..."
    base-url: "https://api.openai.com/v1"  # optional
    headers:
      X-Custom-Header: "value"  # optional
    proxy-url: "socks5://proxy:1080"  # optional
```

**Available Models**:
- `gpt-4o` - GPT-4 Optimized
- `gpt-4-turbo` - GPT-4 Turbo
- `gpt-3.5-turbo` - GPT-3.5 Turbo

---

### 3. Gemini
**Provider**: Google  
**Config Section**: `gemini-api-key`

```yaml
gemini-api-key:
  - api-key: "AIzaSy..."
    base-url: "https://generativelanguage.googleapis.com"  # optional
    headers:
      X-Custom-Header: "value"  # optional
    proxy-url: "socks5://proxy:1080"  # optional
```

**Available Models**:
- `gemini-2.5-pro` - Gemini 2.5 Pro (Latest)
- `gemini-2.5-pro-preview-06-05` - Gemini 2.5 Pro Preview
- `gemini-2.5-flash` - Gemini 2.5 Flash (Fast)
- `gemini-3-pro-preview` - Gemini 3 Pro Preview (NEW)
- `gemini-3-pro` - Falls back to `gemini-3-pro-preview`

**Note**: Gemini 3 Pro automatically falls back to preview version if stable not available.

---

### 4. Qwen
**Provider**: Alibaba Cloud  
**Config Section**: `openai-compatibility`

```yaml
openai-compatibility:
  - name: "qwen"
    base-url: "https://dashscope.aliyuncs.com/compatible-mode/v1"
    api-key-entries:
      - api-key: "sk-..."
        proxy-url: "socks5://proxy:1080"  # optional
```

**Available Models**:
- `qwen-max` - Qwen Max (Most capable)
- `qwen-plus` - Qwen Plus (Fast)
- `qwen-turbo` - Qwen Turbo (Ultra-fast)

---

### 5. Auggie (NEW)
**Provider**: Augment Code  
**Config Section**: `auggie`  
**Requirements**: Auggie CLI installed (`npm install -g @augmentcode/auggie`)

```yaml
auggie:
  enabled: true
  cli_path: "auggie"                      # Path to auggie binary
  session_token: "${AUGMENT_SESSION_AUTH}"  # From: auggie tokens print
  timeout: 300                            # Per-request timeout (seconds)
  max_concurrent: 5                       # Max concurrent requests
  models_cache_ttl: 3600                  # Model cache TTL (seconds)
  
  # Optional: Multiple instances for load balancing
  instances:
    - name: "primary"
      session_token: "${AUGMENT_SESSION_AUTH}"
    - name: "secondary"
      session_token: "${AUGMENT_SESSION_AUTH_2}"
```

**Setup Steps**:
1. Install Auggie CLI: `npm install -g @augmentcode/auggie`
2. Authenticate: `auggie login`
3. Get token: `auggie tokens print`
4. Set environment: `export AUGMENT_SESSION_AUTH="<token>"`
5. Configure in config.yaml

**Available Models**: Retrieved dynamically from Auggie CLI

---

### 6. Cursor Agent (NEW)
**Provider**: Cursor  
**Config Section**: `cursor-agent`  
**Requirements**: Cursor Agent CLI installed

```yaml
cursor-agent:
  enabled: false
  binary-path: "cursor-agent"           # Path to cursor-agent binary
  timeout: "300s"                       # Per-request timeout
  max-retries: 3                        # Max retries for failures
  environment:                          # Optional env vars
    CURSOR_API_KEY: "${env:CURSOR_API_KEY}"
    CURSOR_PROJECT: "${env:CURSOR_PROJECT}"
```

**Setup Steps**:
1. Install Cursor Agent CLI
2. Configure API key (if required)
3. Enable in config.yaml
4. Restart VibeProxy

**Available Models**: Depends on Cursor Agent installation

---

## API Parameter Usage

When making API requests to VibeProxy, use the model name as shown in the "Available Models" sections:

```bash
# Example: Using Gemini 3 Pro
curl -X POST http://localhost:8317/v1/chat/completions \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-3-pro",
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# Example: Using Auggie
curl -X POST http://localhost:8317/v1/chat/completions \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

---

## Environment Variables

VibeProxy supports environment variable expansion in config.yaml:

```yaml
# These will be expanded at startup
claudeSessionToken: "${CLAUDE_SESSION_TOKEN}"
augieSessionToken: "${AUGMENT_SESSION_AUTH}"
cursorApiKey: "${env:CURSOR_API_KEY}"
```

---

## Fallback Behavior

### Gemini 3 Pro
When requesting `gemini-3-pro`:
1. Tries `gemini-3-pro` first
2. If unavailable, automatically falls back to `gemini-3-pro-preview`
3. User gets transparent fallback - no error

---

## Troubleshooting

### Service Not Appearing in UI
- Check config.yaml for typos in section names
- Verify binary/CLI is installed and in PATH
- Check authentication credentials are valid

### Model Not Available
- Verify API key has access to model
- Check for quota limits
- Ensure model name matches exactly (case-sensitive)

### Connection Issues
- Verify proxy-url format if using proxy
- Check firewall/network settings
- Review VibeProxy logs for details

---

## Quick Reference

| Service | Config Section | API Parameter | Status |
|---------|---|---|---|
| Claude | `claude-api-key` | `claude-*-*` | ✅ Active |
| Codex | `codex-api-key` | `gpt-*` | ✅ Active |
| Gemini | `gemini-api-key` | `gemini-*` | ✅ Active |
| Qwen | `openai-compatibility` | `qwen-*` | ✅ Active |
| Auggie | `auggie` | Dynamic | ✅ New |
| Cursor Agent | `cursor-agent` | Dynamic | ✅ New |

