# PR Review Adoption Summary

Reviewed against `automazeio/vibeproxy` pull requests visible on 2026-04-09.

## Adopted

- `#315` Fix OpenAI SSE relaying for Droid custom models
  - Added SSE framing, chunked decoding, and response relaying helpers.
  - Updated `ThinkingProxy` to normalize streamed event responses before forwarding.
- `#322` Fix Gemini personal account authentication flow
  - Switched Gemini auth arguments to `--project_id GOOGLE_ONE -login`.
  - Removed the timed newline that forced the default-project branch.
  - Updated Gemini help text.
- `#295` Opus 4.6 / Sonnet 4.6 support + prompt cache invalidation fix
  - Removed the cache-breaking JSON rewrite path by preserving request structure for Claude thinking rewrites.
  - Extended adaptive-thinking detection to Sonnet 4.6+ and 128K-capable adaptive models.
  - Added adaptive `output_config.effort` injection when missing.
- `#288` Opt-in fast tier for Codex GPT requests
  - Added a Codex UI toggle and persisted setting.
  - Injects `service_tier=priority` only for eligible Responses API requests when the client did not already specify a tier.
- `#304` Allow bundling a custom CLIProxyAPIPlus binary for local testing
  - Added `CLI_PROXY_API_PLUS_PATH` support to `create-app-bundle.sh`.
  - Documented the override in `README.md` and `INSTALLATION.md`.

## Reviewed But Not Adopted

- Auto-generated CLIProxyAPIPlus bump PRs such as `#328`, `#324`, `#321`, `#320`, `#319`, `#317`, `#316`, `#314`, `#308`, `#305`, `#303`, `#298`, `#297`, `#291`, `#289`, `#287`, `#284`, `#282`, `#280`
  - Skipped because they are binary-version bumps rather than code changes we can safely evaluate from this checkout.
- `#293` Usage monitoring, model groups, and UI enhancements
  - Skipped for now because it is large, invasive, and mixes multiple product features with meaningful regression surface.
- `#188` Add proxy URL settings UI and config handling
  - Skipped because it is broader configuration UX work, not a small targeted fix.
- `#153` Add Windows port project
  - Skipped because this repo is currently focused on the macOS app.
- `#213` / `#275` Kimi and OpenClaw additions
  - Skipped as narrower provider-specific features relative to the bug fixes above.

## Already Reflected In This Checkout

- `#301` Custom OpenAI-compatible providers UI/config work
- `#310` Copilot Claude alias support
- `#251` Per-account disable/enable toggle
- `#272` macOS 13 support
- Much of `#166` Amp CLI OAuth routing work
