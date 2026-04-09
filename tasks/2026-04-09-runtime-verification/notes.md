# Runtime Verification

Started: 2026-04-09

## Environment

- App process running: `/Applications/VibeProxy.app/Contents/MacOS/CLIProxyMenuBar`
- Bundled backend running: `/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus -config /Applications/VibeProxy.app/Contents/Resources/config.yaml`
- Proxy base URL: `http://127.0.0.1:8317`
- Active provider surface during this pass: OpenAI only

## Live Model Inventory

`GET /v1/models` returned 13 OpenAI-owned models:

- `gpt-5.1`
- `gpt-5.1-codex`
- `gpt-5.1-codex-mini`
- `gpt-5.1-codex-max`
- `gpt-5.2`
- `gpt-5.2-codex`
- `gpt-5.3-codex-spark`
- `gpt-5.4-mini`
- `gpt-5`
- `gpt-5-codex`
- `gpt-5-codex-mini`
- `gpt-5.3-codex`
- `gpt-5.4`

No Claude/Gemini/Qwen/Copilot models were advertised by the running instance during this pass.

## Direct Server Checks

### Basic server behavior

- `OPTIONS /v1/responses` returned `204 No Content`
- CORS headers were present:
  - `Access-Control-Allow-Origin: *`
  - `Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS`
  - `Access-Control-Allow-Headers: *`

### `/v1/responses` matrix

All 13 advertised OpenAI models returned `200` and completed successfully with a minimal prompt.

Observed response highlights:

- All returned text payload equivalent to `OK`
- Codex-family models reported reasoning efforts such as `medium` or `high`
- Non-Codex GPT models often reported `none`
- `gpt-5.3-codex-spark` returned `service_tier: auto`
- Most others returned `service_tier: default`

### `/v1/chat/completions`

Verified successful non-stream completions for:

- `gpt-5.2`
- `gpt-5.2-codex`
- `gpt-5.4-mini`

All returned `200` with `finish_reason: stop` and the expected `OK` output.

### Streaming

Verified streaming for both:

- `/v1/responses`
- `/v1/chat/completions`

Observed:

- `Content-Type: text/event-stream`
- Valid SSE framing
- `/v1/responses` emitted OpenAI Responses events such as `response.created`
- `/v1/chat/completions` emitted chat chunks and `[DONE]`

### Tool calling

Verified tool calling on both APIs with a synthetic `get_weather` function:

- `/v1/responses` returned output types `reasoning` and `function_call`
- `/v1/chat/completions` returned `finish_reason: tool_calls`

In both cases the tool arguments correctly targeted `{"city":"London"}`.

### Caching

Provider-side caching is working through VibeProxy.

Repeated long-prompt `gpt-5.2-codex` requests showed:

- first observed repeated runs in this pass: `cached_tokens = 3456`
- subsequent runs remained stable at `cached_tokens = 3456`

This confirms real cache reuse at the provider layer through the proxy path.

### Response persistence and chaining

These features do not currently behave like native Responses API server-side persistence:

- Sending `store: true` returned `store: false`
- Sending `previous_response_id` returned `200`, but the response came back with `previous_response_id: null`
- In live follow-up tests, this did not preserve prior-turn meaning the way a native response thread would

Conclusion: server-side response-thread persistence/chaining is not effectively preserved through the current VibeProxy path.

### Error handling

Error semantics are functional but not especially clean:

- invalid model returned `502` with `unknown provider for model definitely-not-a-model`
- missing model also returned `502` with `unknown provider for model`

This works as failure signaling, but looks more like backend/provider routing failure than polished client validation.

### Path alias behavior

- `/v1/responses` works
- `/api/v1/responses` returned `404 Not Found` on the installed app in this environment

That means the production runtime surface is narrower than some internal path handling suggests.

### Service tier behavior

Explicitly sending `service_tier: priority` still returned `service_tier: default` in the resulting response for `gpt-5.2-codex`.

Conclusion: fast-tier behavior is not verified live, and may be ignored or normalized away downstream.

## Droid Integration Checks

### Custom OpenAI models

All three custom OpenAI entries succeeded:

- `custom:GPT-5.2-Codex-3`
- `custom:GPT-5.2-Codex-(High)-4`
- `custom:GPT-5.2-5`

Each returned the expected `OK` output.

### Custom Claude models

All three custom Claude entries failed:

- `custom:CC:-Opus-4.6-(Max)-0`
- `custom:CC:-Sonnet-4.6-(High)-1`
- `custom:CC:-Sonnet-4.6-2`

Backend reason from Droid logs:

- `502 {"error":{"message":"unknown provider for model claude-sonnet-4-6"...}}`

This matches the live server state, where only OpenAI models were exposed.

### Droid session continuity

Verified practical client-side continuity with the proxy-backed Codex model:

1. Started a Droid session and asked it to remember `LIME-ROCKET-731`
2. Continued that same session with `-s <session-id>`
3. Droid correctly recalled the codeword

This confirms usable session continuity in Droid.

Important nuance:

- continuity works at the Droid client/session layer
- continuity does not appear to be preserved as native server-side `previous_response_id` threading through VibeProxy

## Overall Status

### Works

- OpenAI model discovery
- `/v1/responses`
- `/v1/chat/completions`
- streaming SSE on both APIs
- tool calling on both APIs
- provider-side caching
- Droid usage of the custom OpenAI models
- Droid session continuation

### Works with caveats

- error handling is present but uses rough `502 unknown provider` semantics
- service tier fields do not verify as requested or forced

### Not working or not present in this runtime

- Claude custom models, because no Claude provider/models were active
- native-style Responses API persistence semantics (`store`, `previous_response_id`)
- `/api/v1/responses` alias path on the installed app

## Unverified In This Pass

- Image generation
- Web-search-backed model features
- Background response workflows
- Non-OpenAI providers, because they were not active in the running instance
