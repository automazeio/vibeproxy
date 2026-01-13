# Amp CLI Setup Guide

This guide explains how to configure Amp CLI to work with VibeProxy, enabling you to use both Factory and Amp through a single proxy server.

## Overview

VibeProxy integrates with Amp CLI by:
- Routing Amp login directly to ampcode.com (preserves OAuth cookies)
- Routing model requests through CLIProxyAPI (uses your local subscriptions)
- Automatically falling back to Amp credits for models you haven't authenticated locally

## Prerequisites

- VibeProxy installed and running
- Amp CLI installed (`amp --version` to verify)

## Quick Setup

### 1. Configure Amp URL

```bash
mkdir -p ~/.config/amp
echo '{"amp.url": "http://localhost:8317"}' > ~/.config/amp/settings.json
```

### 2. Login to Amp

```bash
amp login
```

Your browser will open to ampcode.com for authentication. After login, your API key is saved to `~/.local/share/amp/secrets.json`.

### 3. Restart VibeProxy

Quit and relaunch VibeProxy from the menu bar. VibeProxy automatically fixes the secrets file format on startup.

### 4. Test

```bash
amp "Say hello"
```

## Authenticate Your Subscriptions (Recommended)

To use your Claude Max, ChatGPT Plus, or Gemini subscriptions instead of Amp credits:

```bash
# Claude (Anthropic) - uses your Claude Max/Pro subscription
/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus \
  -config /Applications/VibeProxy.app/Contents/Resources/config.yaml \
  -claude-login

# ChatGPT (OpenAI) - uses your ChatGPT Plus/Pro subscription
/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus \
  -config /Applications/VibeProxy.app/Contents/Resources/config.yaml \
  -codex-login

# Gemini (Google) - uses your Google AI subscription
/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus \
  -config /Applications/VibeProxy.app/Contents/Resources/config.yaml \
  -login
```

After authenticating, restart VibeProxy. Your subscriptions will be used automatically.

## How It Works

```
Amp CLI
  │
  ▼
http://localhost:8317 (VibeProxy)
  │
  ├─► /auth/cli-login ──────────► https://ampcode.com (direct redirect)
  │                                      │
  │                               Browser completes OAuth
  │                                      │
  │                               API key saved locally
  │
  ├─► /provider/* ──────────────► CLIProxyAPI:8318
  │                                      │
  │                               ┌──────┴──────┐
  │                               │             │
  │                         Local OAuth?    No OAuth?
  │                               │             │
  │                         Use your        Use Amp
  │                         subscription    credits
  │
  └─► /api/* (management) ──────► https://ampcode.com
```

### Model Routing Priority

1. **Local OAuth available** → Uses your subscription (free)
2. **No local OAuth** → Falls back to Amp credits

## Troubleshooting

### "auth_unavailable: no auth available"

The apiKey field is missing from secrets.json. This should be fixed automatically on restart, but if it persists:

```bash
# Check if apiKey exists
cat ~/.local/share/amp/secrets.json | grep apiKey

# If missing, restart VibeProxy or run:
python3 -c "import json,os; f=os.path.expanduser('~/.local/share/amp/secrets.json'); d=json.load(open(f)); d['apiKey']=d.get('apiKey@https://ampcode.com/',d.get('apiKey@http://localhost:8317','')); json.dump(d,open(f,'w'),indent=2)"
```

### "insufficient_quota"

Your Amp account is out of credits. Either:
- Add credits at ampcode.com
- Authenticate local providers (Claude, Codex) to use your subscriptions instead

### OAuth token expired

Re-authenticate the provider:

```bash
# Check token files
ls -la ~/.cli-proxy-api/*.json

# Re-login (example for Claude)
/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus \
  -config /Applications/VibeProxy.app/Contents/Resources/config.yaml \
  -claude-login
```

### Login fails in browser

Make sure VibeProxy is running before attempting `amp login`.

## Benefits

- **Use your subscriptions** - Claude Max, ChatGPT Plus work through Amp
- **Automatic fallback** - Amp credits used only when needed
- **One proxy** - Factory and Amp share the same setup
- **Cost optimization** - Minimize Amp credit usage

## Additional Resources

- [Amp CLI Documentation](https://ampcode.com/manual)
- [Factory Setup Guide](FACTORY_SETUP.md)
