# Using OpenCode with VibeProxy

A simplified guide for using [OpenCode](https://opencode.ai) with your personal Claude, ChatGPT, and Google subscriptions through VibeProxy.

## What is This?

This guide shows you how to use OpenCode with your personal **ChatGPT Plus/Pro** and **Google Antigravity** subscriptions instead of paying for separate API access. VibeProxy acts as a bridge that handles authentication and routing automatically.

**How it works:**

```
OpenCode  →  VibeProxy  →  [OAuth Authentication]  →  Codex / Antigravity APIs
```

VibeProxy manages OAuth tokens, auto-refreshes them, routes requests, and handles API format conversion — all automatically in the background.

## Prerequisites

- macOS 13.0+ (Ventura or later)
- Active **ChatGPT Plus/Pro** subscription for OpenAI Codex access
- **Google account** for Antigravity access (provides Claude via Gemini + Gemini 3 models)
- OpenCode installed: see [OpenCode Installation Guide](https://opencode.ai/docs/getting-started)

## Step 1: Install VibeProxy

1. **Download [VibeProxy.app](https://github.com/automazeio/vibeproxy/releases)** from the releases page or build from source
2. **Install**: Drag `VibeProxy.app` to your `/Applications` folder
3. **Launch**: Open VibeProxy from Applications
   - If macOS blocks it: Right-click → Open, then click "Open" in the dialog

## Step 2: Connect Your Accounts

Once VibeProxy is running:

1. Click the **VibeProxy menu bar icon**
2. Select **"Open Settings"**
3. Click **"Connect"** next to Codex
   - Your browser will open for authentication
   - Complete the login process with your ChatGPT account
   - VibeProxy will automatically detect when you're authenticated
4. Click **"Connect"** next to Antigravity
   - Sign in with your Google account
   - Grant permissions for AI model access
   - This provides access to **Gemini 3 Pro/Flash** and **Claude** models via Antigravity
   - VibeProxy will automatically save your credentials

> [!TIP]
> The server starts automatically and runs on port **8317**

## Step 3: Configure OpenCode

Edit your OpenCode configuration file at `~/.config/opencode/opencode.json`:

```jsonc
{
  "provider": {
    "vibeproxy_openai": {
      "npm": "@ai-sdk/openai",
      "name": "VibeProxy Codex",
      "options": {
        "baseURL": "http://127.0.0.1:8317/api/provider/openai/v1",
        "apiKey": "dummy-not-used",
        "setCacheKey": true,
        "timeout": 600000,
        "reasoningEffort": "medium",
        "reasoningSummary": "auto",
        "textVerbosity": "medium",
        "include": [
          "reasoning.encrypted_content"
        ],
        "store": false
      },
      "models": {
        "gpt-5.1-codex": {
          "name": "GPT-5.1 Codex",
          "attachment": true,
          "limit": {
            "context": 272000,
            "output": 128000
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          },
          "variants": {
            "low": {
              "reasoningEffort": "low",
              "reasoningSummary": "auto",
              "textVerbosity": "medium"
            },
            "medium": {
              "reasoningEffort": "medium",
              "reasoningSummary": "auto",
              "textVerbosity": "medium"
            },
            "high": {
              "reasoningEffort": "high",
              "reasoningSummary": "detailed",
              "textVerbosity": "medium"
            },
            "xhigh": {
              "reasoningEffort": "xhigh",
              "reasoningSummary": "detailed",
              "textVerbosity": "medium"
            }
          }
        },
        "gpt-5.1-codex-max": {
          "name": "GPT-5.1 Codex Max",
          "attachment": true,
          "limit": {
            "context": 272000,
            "output": 128000
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          },
          "variants": {
            "low": {
              "reasoningEffort": "low",
              "reasoningSummary": "detailed",
              "textVerbosity": "medium"
            },
            "medium": {
              "reasoningEffort": "medium",
              "reasoningSummary": "detailed",
              "textVerbosity": "medium"
            },
            "high": {
              "reasoningEffort": "high",
              "reasoningSummary": "detailed",
              "textVerbosity": "medium"
            },
            "xhigh": {
              "reasoningEffort": "xhigh",
              "reasoningSummary": "detailed",
              "textVerbosity": "medium"
            }
          }
        },
        "gpt-5.2-codex": {
          "name": "GPT-5.2 Codex",
          "attachment": true,
          "limit": {
            "context": 272000,
            "output": 128000
          },
          "modalities": {
            "input": ["text", "image"],
            "output": ["text"]
          },
          "variants": {
            "low": {
              "reasoningEffort": "low",
              "reasoningSummary": "auto",
              "textVerbosity": "medium"
            },
            "medium": {
              "reasoningEffort": "medium",
              "reasoningSummary": "auto",
              "textVerbosity": "medium"
            },
            "high": {
              "reasoningEffort": "high",
              "reasoningSummary": "detailed",
              "textVerbosity": "medium"
            }
          }
        }
      }
    },
    "vibeproxy_google": {
      "npm": "@ai-sdk/openai",
      "name": "VibeProxy Antigravity",
      "options": {
        "baseURL": "http://127.0.0.1:8317/api/provider/antigravity/v1",
        "apiKey": "dummy-not-used",
        "setCacheKey": true,
        "timeout": 600000
      },
      "models": {
        "gemini-3-pro-preview": {
          "name": "Gemini 3 Pro",
          "limit": {
            "context": 1048576,
            "output": 65535
          },
          "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"]
          },
          "variants": {
            "low": {
              "thinkingLevel": "low"
            },
            "high": {
              "thinkingLevel": "high"
            }
          }
        },
        "gemini-3-pro-image-preview": {
          "name": "Gemini 3 Pro Image",
          "limit": {
            "context": 1048576,
            "output": 65535
          },
          "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"]
          },
          "variants": {
            "low": {
              "thinkingLevel": "low"
            },
            "high": {
              "thinkingLevel": "high"
            }
          }
        },
        "gemini-3-flash-preview": {
          "name": "Gemini 3 Flash",
          "limit": {
            "context": 1048576,
            "output": 65536
          },
          "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"]
          },
          "variants": {
            "minimal": {
              "thinkingLevel": "minimal"
            },
            "low": {
              "thinkingLevel": "low"
            },
            "medium": {
              "thinkingLevel": "medium"
            },
            "high": {
              "thinkingLevel": "high"
            }
          }
        },
        "gemini-claude-sonnet-4-5": {
          "name": "Claude Sonnet 4.5",
          "limit": {
            "context": 200000,
            "output": 64000
          },
          "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"]
          }
        },
        "gemini-claude-sonnet-4-5-thinking": {
          "name": "Claude Sonnet 4.5 Thinking",
          "limit": {
            "context": 200000,
            "output": 64000
          },
          "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"]
          },
          "variants": {
            "low": {
              "thinkingConfig": {
                "thinkingBudget": 8192
              }
            },
            "max": {
              "thinkingConfig": {
                "thinkingBudget": 32768
              }
            }
          }
        },
        "gemini-claude-opus-4-5-thinking": {
          "name": "Claude Opus 4.5 Thinking",
          "limit": {
            "context": 200000,
            "output": 64000
          },
          "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"]
          },
          "variants": {
            "low": {
              "thinkingConfig": {
                "thinkingBudget": 8192
              }
            },
            "max": {
              "thinkingConfig": {
                "thinkingBudget": 32768
              }
            }
          }
        }
      }
    }
  },
  "$schema": "https://opencode.ai/config.json"
}
```

## Step 4: Use OpenCode

1. **Launch OpenCode**:
   ```bash
   opencode
   ```

2. **Select your model** using `/model` command:
   - **Codex models**: `gpt-5.1-codex`, `gpt-5.2-codex`, `gpt-5.1-codex-max`
   - **Antigravity models**: `gemini-3-pro-preview`, `gemini-claude-sonnet-4-5`, etc.

3. **Use model variants** for different reasoning levels:
   - `/model gpt-5.1-codex:high` - High reasoning effort
   - `/model gemini-3-flash-preview:medium` - Medium thinking level

4. **Start coding!** OpenCode will now route all requests through VibeProxy.

## Available Models

### OpenAI Codex Models (via VibeProxy Codex)

| Model | Description |
|-------|-------------|
| `gpt-5.1-codex` | Fast Codex for everyday coding tasks |
| `gpt-5.1-codex-max` | Max Codex optimized for long-horizon agentic coding |
| `gpt-5.2-codex` | Latest Codex with improved reasoning |

**Reasoning Effort Variants:**
- `:low` - Low reasoning effort
- `:medium` - Medium reasoning effort (default)
- `:high` - High reasoning effort
- `:xhigh` - Extra high reasoning effort (5.1 models only)

### Antigravity Models (via VibeProxy Antigravity)

#### Gemini 3 Models
| Model | Description |
|-------|-------------|
| `gemini-3-pro-preview` | Gemini 3 Pro (Most capable) |
| `gemini-3-pro-image-preview` | Gemini 3 Pro with enhanced vision |
| `gemini-3-flash-preview` | Gemini 3 Flash (Fast and efficient) |

**Thinking Level Variants:**
- `:minimal` - Minimal thinking (Flash only)
- `:low` - Low thinking level
- `:medium` - Medium thinking level (Flash only)
- `:high` - High thinking level

#### Claude Models via Antigravity
| Model | Description |
|-------|-------------|
| `gemini-claude-sonnet-4-5` | Claude Sonnet 4.5 (no thinking) |
| `gemini-claude-sonnet-4-5-thinking` | Claude Sonnet 4.5 with extended thinking |
| `gemini-claude-opus-4-5-thinking` | Claude Opus 4.5 with extended thinking |

**Thinking Budget Variants (Claude models):**
- `:low` - 8K token thinking budget
- `:max` - 32K token thinking budget

## API Endpoints

OpenCode connects to VibeProxy using these endpoints:

| Provider | Base URL |
|----------|----------|
| **Codex** | `http://127.0.0.1:8317/api/provider/openai/v1` |
| **Antigravity** | `http://127.0.0.1:8317/api/provider/antigravity/v1` |

> [!NOTE]
> OpenCode uses `@ai-sdk/openai` npm package for both providers since VibeProxy exposes an OpenAI-compatible API.

## Troubleshooting

### VibeProxy Menu Bar Status
- **Green dot**: Server is running
- **Red dot**: Server is stopped
- **Click the status** to toggle the server on/off

### Connection Issues

| Problem | Solution |
|---------|----------|
| Can't connect to Codex/Antigravity | Re-click "Connect" in VibeProxy settings |
| OpenCode shows connection errors | Make sure VibeProxy server is running (check menu bar) |
| Authentication expired | Disconnect and reconnect the service in VibeProxy |
| Port 8317 already in use | Quit any other instances of VibeProxy or CLIProxyAPI |
| Models not appearing | Restart OpenCode after updating config |

### Verification Checklist

1. VibeProxy is running (menu bar icon shows green)
2. Services (Codex and Antigravity) show as "Connected" in settings
3. OpenCode config has the provider configurations
4. OpenCode can list custom models with `/model`
5. Test with a simple prompt: "what day is it?"

### Config File Location

OpenCode configuration is stored at:
```
~/.config/opencode/opencode.json
```

## Tips

- **Launch at Login**: Enable in VibeProxy settings to auto-start the server
- **Auth Folder**: Click "Open Folder" in settings to view authentication tokens
- **Timeout**: Both providers use 600s (10 min) timeout for long-running requests
- **Caching**: `setCacheKey: true` enables response caching for identical requests

## Security

- All authentication tokens are stored locally in `~/.cli-proxy-api/`
- Token files are secured with proper permissions (0600)
- VibeProxy only binds to localhost (127.0.0.1)
- All upstream traffic uses HTTPS
- Tokens are auto-refreshed before expiration

---

> [!WARNING]
> <br>**By using VibeProxy, you acknowledge and accept the following:**
>
> - **Terms of Service Risk**: This approach may violate the Terms of Service of AI model providers (OpenAI, Google, etc.). You are solely responsible for ensuring compliance with all applicable terms and policies.
>
> - **Account Risk**: Model providers may detect this usage pattern and take punitive action, including but not limited to account suspension, permanent ban, or loss of access to paid subscriptions.
>
> - **No Guarantees**: Providers may change their APIs, authentication mechanisms, or policies at any time, rendering this method inoperable without notice.
>
> - **Assumption of Risk**: By proceeding, you assume all legal, financial, and technical risks. The authors and contributors of this guide and CLIProxyAPI bear no responsibility for any consequences arising from your use of this method.
>
> **Use at your own risk. Proceed only if you understand and accept these risks.**

---

## References

- **OpenCode**: [https://opencode.ai](https://opencode.ai)
- **VibeProxy**: [https://github.com/automazeio/vibeproxy](https://github.com/automazeio/vibeproxy)
- **CLIProxyAPI**: [https://github.com/router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)

---

**Need Help?**
- Report issues: [GitHub Issues](https://github.com/automazeio/vibeproxy/issues)
- VibeProxy by [Automaze, Ltd.](https://automaze.io)
