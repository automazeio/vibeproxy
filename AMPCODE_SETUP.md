# Amp CLI Setup Guide

This guide explains how to configure Amp CLI to work with VibeProxy, enabling you to use your existing subscriptions (Claude Max, ChatGPT Plus, Gemini) through Amp CLI.

## Overview

VibeProxy integrates with Amp CLI by:
- Routing Amp login directly to ampcode.com (preserves OAuth cookies)
- Routing model requests through CLIProxyAPI (uses your local subscriptions)
- **No fallback** - you must authenticate the providers you want to use

## Prerequisites

- VibeProxy installed and running
- Amp CLI installed (`amp --version` to verify)
- Active subscription (Claude Max, ChatGPT Plus, or Gemini)

## Setup

### 1. Configure Amp URL

```bash
mkdir -p ~/.config/amp
echo '{"amp.url": "http://localhost:8317"}' > ~/.config/amp/settings.json
```

### 2. Authenticate Your Providers (Required)

You must authenticate at least one provider to use Amp through VibeProxy:

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

### 3. Login to Amp (Optional)

If you want to use Amp's management features:

```bash
amp login
```

Your browser will open to ampcode.com for authentication.

### 4. Restart VibeProxy

Quit and relaunch VibeProxy from the menu bar.

### 5. Test

```bash
amp "Say hello"
```

## How It Works

```text
Amp CLI
  │
  ▼
http://localhost:8317 (VibeProxy)
  │
  ├─► /auth/cli-login ──────────► https://ampcode.com (direct redirect)
  │
  ├─► /provider/* ──────────────► CLIProxyAPI:8318
  │                                      │
  │                               Local OAuth token?
  │                                      │
  │                               ┌──────┴──────┐
  │                               │             │
  │                              YES           NO
  │                               │             │
  │                         Use your        ERROR
  │                         subscription   (auth_unavailable)
  │
  └─► /api/* (management) ──────► https://ampcode.com
```

## Provider Priority

When logged into multiple providers (Claude, ChatGPT, Gemini, etc.), Amp may pick models from any of them. Use **Provider Priority** to control which providers are active.

### Enable/Disable Providers

In VibeProxy Settings, each provider has a toggle switch:
- **Enabled** (default) - Provider's models are available to Amp
- **Disabled** - Provider's models are excluded from Amp

Changes apply instantly via hot reload - no restart needed.

### Use Cases

- **Single provider mode** - Disable all but one provider to ensure Amp always uses that provider
- **Avoid rate limits** - Disable providers you've hit rate limits on
- **Testing** - Quickly switch between providers to compare responses

### Notes

- When all providers are disabled, Amp falls back to its free tier (rate limited)
- Provider toggles only affect model availability, not authentication status
- You remain logged into disabled providers and can re-enable them anytime

## Troubleshooting

### "auth_unavailable: no auth available"

You haven't authenticated the provider for the model you're trying to use.

**Solution:** Run the appropriate login command:
- For Claude models: `-claude-login`
- For GPT models: `-codex-login`
- For Gemini models: `-login`

Then restart VibeProxy.

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

- **Use your subscriptions** - Claude Max, ChatGPT Plus, Gemini work through Amp
- **No surprise charges** - No fallback to Amp credits
- **Full transparency** - Clear error if provider not authenticated
- **One proxy** - Factory and Amp share the same setup

## Additional Resources

- [Amp CLI Documentation](https://ampcode.com/manual)
- [Factory Setup Guide](FACTORY_SETUP.md)
