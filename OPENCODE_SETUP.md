# Using OpenCode with VibeProxy (Codex + Antigravity)

A short guide to add the **Codex** and **Antigravity** providers to OpenCode using VibeProxy as the local gateway.

## What is This?

This guide shows how to route OpenCode model requests through VibeProxy and expose two providers:
`codex` (OpenAI-compatible endpoint) and `google` (Antigravity models). VibeProxy handles routing at
`http://127.0.0.1:8317`, while OpenCode reads the provider and model definitions from its config.

```
OpenCode  →  VibeProxy  →  Codex / Antigravity Providers  →  Models
```

## Prerequisites

- VibeProxy installed and running (server on port **8317**)
- OpenCode installed
- Codex access (ChatGPT Plus/Pro) if you want Codex models
- Antigravity access (Google account) if you want Antigravity models

## Step 1: Start VibeProxy

1. Launch VibeProxy from `/Applications`
2. Ensure the server is **Running** (menu bar icon)
3. Confirm the port is **8317**

## Step 2: Add Providers to OpenCode

Open your OpenCode configuration file and add the provider block below.

> The config path can vary by install. Common locations:
> - `~/.config/opencode/config.json`
> - `~/.opencode/config.json`
>
> If your OpenCode setup uses a different path, use that location instead.

### Notes on the fields

- `npm`: the AI SDK provider package name. If OpenCode manages provider packages automatically,
  no action is needed. If not, install the package following your OpenCode docs.
- `baseURL`: points to VibeProxy’s local endpoint.
- `apiKey`: fixed string used by VibeProxy for internal routing.
- `variants`: optional per-model presets (e.g., thinking level or budget).
- `modalities`: declare inputs/outputs (e.g., include `"image"` to allow images).
- `attachment`: allow file attachments in UI (useful for some Gemini models).

### Step 2a: Codex Provider

Make sure **Codex** is connected in VibeProxy Settings (click **Connect** next to Codex).

Add this provider block into the same top-level `provider` section:

```json
{
  "provider": {
    "codex": {
      "npm": "@ai-sdk/openai",
      "name": "Codex (VibeProxy)",
      "options": {
        "baseURL": "http://127.0.0.1:8317/v1",
        "apiKey": "dummy-not-used"
      },
      "models": {
        "gpt-5.2-codex": {
          "name": "GPT-5.2 Codex",
          "limit": { "context": 272000, "output": 128000 },
          "modalities": { "input": ["text", "image"], "output": ["text"] },
          "variants": {
            "low": { "reasoningEffort": "low", "reasoningSummary": "auto", "textVerbosity": "medium" },
            "medium": { "reasoningEffort": "medium", "reasoningSummary": "auto", "textVerbosity": "medium" },
            "high": { "reasoningEffort": "high", "reasoningSummary": "detailed", "textVerbosity": "medium" },
            "xhigh": { "reasoningEffort": "xhigh", "reasoningSummary": "detailed", "textVerbosity": "medium" }
          }
        },
        "gpt-5.1-codex": {
          "name": "GPT-5.1 Codex",
          "limit": { "context": 272000, "output": 128000 },
          "modalities": { "input": ["text", "image"], "output": ["text"] },
          "variants": {
            "low": { "reasoningEffort": "low", "reasoningSummary": "auto", "textVerbosity": "medium" },
            "medium": { "reasoningEffort": "medium", "reasoningSummary": "auto", "textVerbosity": "medium" },
            "high": { "reasoningEffort": "high", "reasoningSummary": "detailed", "textVerbosity": "medium" },
            "xhigh": { "reasoningEffort": "xhigh", "reasoningSummary": "detailed", "textVerbosity": "medium" }
          }
        },
        "gpt-5.1-codex-max": {
          "name": "GPT-5.1 Codex Max",
          "limit": { "context": 272000, "output": 128000 },
          "modalities": { "input": ["text", "image"], "output": ["text"] },
          "variants": {
            "low": { "reasoningEffort": "low", "reasoningSummary": "detailed", "textVerbosity": "medium" },
            "medium": { "reasoningEffort": "medium", "reasoningSummary": "detailed", "textVerbosity": "medium" },
            "high": { "reasoningEffort": "high", "reasoningSummary": "detailed", "textVerbosity": "medium" },
            "xhigh": { "reasoningEffort": "xhigh", "reasoningSummary": "detailed", "textVerbosity": "medium" }
          }
        }
      }
    }
  }
}
```

> Variants replace separate `(high)` model entries. Pick `low`, `medium`, `high`, or `xhigh` in your UI.

### Step 2b: Antigravity (Google Provider)

Make sure **Antigravity** is connected in VibeProxy Settings (click **Connect** next to Antigravity).

Add this provider block into the same top-level `provider` section:

```json
{
  "provider": {
    "google": {
      "name": "Google",
      "models": {
        "antigravity-gemini-3-pro": {
          "name": "Gemini 3 Pro (Antigravity)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingLevel": "low" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-gemini-3-flash": {
          "name": "Gemini 3 Flash (Antigravity)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "minimal": { "thinkingLevel": "minimal" },
            "low": { "thinkingLevel": "low" },
            "medium": { "thinkingLevel": "medium" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-claude-sonnet-4-5": {
          "name": "Claude Sonnet 4.5 (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "antigravity-claude-sonnet-4-5-thinking": {
          "name": "Claude Sonnet 4.5 Thinking (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingConfig": { "thinkingBudget": 8192 } },
            "max": { "thinkingConfig": { "thinkingBudget": 32768 } }
          }
        },
        "antigravity-claude-opus-4-5-thinking": {
          "name": "Claude Opus 4.5 Thinking (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingConfig": { "thinkingBudget": 8192 } },
            "max": { "thinkingConfig": { "thinkingBudget": 32768 } }
          }
        }
      }
    }
  }
}
```

> If you already use the `opencode-antigravity-auth` plugin, keep it enabled. Antigravity models
> are listed under the `google` provider in OpenCode.

## Step 3: Use the Models in OpenCode

Restart OpenCode (or reload config) and select any of the new models.

**Codex models:**

- `gpt-5.2-codex`
- `gpt-5.1-codex`
- `gpt-5.1-codex-max`

**Antigravity (Google) models:**

- `antigravity-gemini-3-pro`
- `antigravity-gemini-3-flash`
- `antigravity-claude-sonnet-4-5`
- `antigravity-claude-sonnet-4-5-thinking`
- `antigravity-claude-opus-4-5-thinking`

## Troubleshooting

- **Connection refused / 404**: VibeProxy isn’t running or the port is different. Confirm it’s
  running on `http://127.0.0.1:8317`.
- **Model not found**: Ensure the model key matches the `models` entries exactly.
- **Auth errors**: Re-check the `apiKey` and the `baseURL` path. For Codex, confirm you connected
  Codex in VibeProxy Settings.
