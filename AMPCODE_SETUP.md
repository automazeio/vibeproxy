# Amp CLI Setup Guide

VibeProxy supports **Amp classic mode only** for local model inference. The current default Amp CLI (Amp Neo) runs inference in Amp's cloud actor and does not send model requests to `localhost`, so VibeProxy cannot redirect Neo inference to your local subscriptions.

To avoid Amp credit usage, run the pinned classic CLI shown below. Do not use the current default `amp` command for inference through VibeProxy.

## Prerequisites

- VibeProxy installed and running
- Node.js with `npx`
- At least one provider authenticated in VibeProxy (Claude, ChatGPT/Codex, or Gemini)

## 1. Point Amp at VibeProxy

```bash
mkdir -p ~/.config/amp
printf '%s\n' '{"amp.url": "http://localhost:8317"}' > ~/.config/amp/settings.json
```

## 2. Authenticate local providers

Use VibeProxy's provider controls, or run the bundled backend login command for the provider you need:

```bash
# Claude Max/Pro
/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus \
  -config /Applications/VibeProxy.app/Contents/Resources/config.yaml \
  -claude-login

# ChatGPT Plus/Pro (Codex OAuth)
/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus \
  -config /Applications/VibeProxy.app/Contents/Resources/config.yaml \
  -codex-login

# Gemini
/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus \
  -config /Applications/VibeProxy.app/Contents/Resources/config.yaml \
  -login
```

Restart VibeProxy after authenticating from the command line.

## 3. Run the pinned classic CLI

```bash
npx -y @ampcode/cli@0.0.1779896748-g596c49 --take-me-back "Say hello"
```

For a convenient stable command, create a wrapper:

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/amp-classic <<'EOF'
#!/bin/sh
exec npx -y @ampcode/cli@0.0.1779896748-g596c49 --take-me-back "$@"
EOF
chmod +x ~/.local/bin/amp-classic
```

Then use:

```bash
amp-classic "Say hello"
```

If `~/.local/bin` is not already on your `PATH`, add it before using the short command.

Use the same pinned wrapper for Amp management commands such as login if needed. Do not substitute the latest `amp` binary: current Amp Neo is not compatible with local inference interception.

The current Amp cloud API rejects classic-format thread uploads. VibeProxy acknowledges those uploads locally so classic commands can exit cleanly; those threads are not synchronized to ampcode.com.

## How routing works

```text
Pinned Amp classic CLI
  │
  ▼
http://localhost:8317 (VibeProxy ThinkingProxy)
  │
  ├─► /api/provider/anthropic/v1/* ─► /v1/*
  ├─► /api/provider/openai/v1/*    ─► /v1/*
  ├─► /api/provider/google/v1beta/* ─► /v1beta/*
  ├─► Google v1beta1 publisher paths ─► /v1beta/models/*
  │                                      │
  │                                      ▼
  │                               CLIProxyAPI:8318
  │                               (local provider OAuth)
  │
  ├─► /auth/cli-login ─────────────► https://ampcode.com
  └─► Amp management requests ─────► https://ampcode.com
```

The path compatibility mapping is needed because the bundled CLIProxyAPIPlus no longer registers its old Amp-specific `/api/provider/*` routes, while its generic Anthropic, OpenAI, and Gemini endpoints remain available.

## Provider controls

VibeProxy's provider toggles control which locally authenticated providers and models CLIProxyAPI exposes. Disabling a provider does **not** make Amp Neo fall back through VibeProxy; Neo inference remains cloud-hosted and unsupported. If classic mode reports `auth_unavailable: no auth available`, authenticate or re-enable the provider needed by the selected model.

## Troubleshooting

### Requests do not appear in VibeProxy logs

Confirm the command includes both the pinned package version and `--take-me-back`. The current default Amp Neo client does not send inference requests through VibeProxy.

### `auth_unavailable: no auth available`

Authenticate the provider required by the requested model, then restart VibeProxy if login was performed with the backend command.

### Amp provider request returns 404

Confirm VibeProxy is running on port 8317 and the client is configured with `"amp.url": "http://localhost:8317"`. The ThinkingProxy compatibility layer maps classic Amp provider paths to the backend's generic endpoints.

### Login fails in the browser

Make sure VibeProxy is running before invoking login through the pinned classic wrapper.

## Additional resources

- [Amp CLI Documentation](https://ampcode.com/manual)
- [Factory Setup Guide](FACTORY_SETUP.md)
