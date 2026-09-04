# Codex Desktop Setup

Use VibeProxy as Codex Desktop's single model provider when you want OpenAI/Codex models and Z.AI GLM models available from the same local endpoint.

## Requirements

- VibeProxy is running on `http://localhost:8317`
- Codex is connected in VibeProxy
- Z.AI GLM has an API key added in VibeProxy

Verify the proxy exposes both model families:

```bash
curl http://localhost:8317/v1/models
```

You should see OpenAI/Codex models such as `gpt-5.5` and Z.AI models such as `glm-5.2`.

## Codex Config

Codex selects one `model_provider` for a thread. To switch between OpenAI and GLM from the Codex model picker, point Codex at VibeProxy and let VibeProxy route by model name.

Add this to `~/.codex/config.toml`:

```toml
model = "gpt-5.5"
model_provider = "vibeproxy"
model_catalog_json = "/Users/YOU/.codex/model_catalog_vibeproxy.json"

[model_providers.vibeproxy]
name = "VibeProxy"
base_url = "http://localhost:8317/v1"
wire_api = "responses"
experimental_bearer_token = "dummy-not-used"
```

## Model Picker Catalog

Codex Desktop's picker is catalog-driven. If a GLM model does not appear in the picker, create a custom catalog that contains the built-in Codex models plus a `glm-5.2` entry.

The catalog entry only controls display and model capabilities. Provider routing still comes from the single `model_provider = "vibeproxy"` setting above.

After changing `model_catalog_json`, restart Codex Desktop so it reloads the catalog.

## Smoke Tests

```bash
curl http://localhost:8317/v1/responses \
  -H 'Content-Type: application/json' \
  -d '{"model":"glm-5.2","input":"Say ok.","max_output_tokens":512}'
```

Then select `glm-5.2` in Codex Desktop or start a CLI smoke test:

```bash
codex exec --model glm-5.2 "Reply with exactly: glm-ok"
```
