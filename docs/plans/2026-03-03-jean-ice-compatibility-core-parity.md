# Jean ICE Compatibility-Core Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build full cross-platform feature parity in Jean ICE using `cli-proxy-api-plus` as the auth/routing engine and a Jean edge proxy layer for compatibility behavior.

**Architecture:** Jean runs a Rust edge proxy on a user-facing port and launches `cli-proxy-api-plus` as a managed sidecar on an internal port. The edge proxy owns request/response compatibility transforms (thinking/reasoning, model groups, qualified model IDs, diagnostics), while the sidecar owns provider auth and base upstream routing. Frontend (Tauri/React) controls settings, account management, and observability.

**Tech Stack:** Tauri v2, Rust (`tokio`, `axum`/`hyper`, `serde`, `reqwest`), TypeScript/React, Vitest, Playwright, sidecar packaging.

---

## Compatibility Contract (must be true before release)

1. Jean accepts OpenAI-compatible `/v1/*` requests and Claude-compatible message flows without changing client integrations.
2. Jean preserves provider auth/account behavior by using `~/.cli-proxy-api` and `cli-proxy-api-plus` login modes.
3. Jean supports providers: Claude, Codex/OpenAI, GitHub Copilot, Gemini, Qwen, Antigravity, Z.AI.
4. Jean supports proxy toggle, start-with-app, and configurable public proxy port.
5. Jean supports manual model groups with round-robin and same-request failover.
6. Jean supports qualified model IDs `{owned_by}/{model_id}` and provider-pinned routing.
7. Jean supports reasoning transforms (`-thinking-*`, `-reasoning-*`) and diagnostics APIs (`/vibe/status`, `/vibe/usage`, `/vibe/usage/reset`).
8. Jean tracks usage and account rotation state (including next account index) and exposes it in diagnostics + UI.

Execution discipline during implementation: `@superpowers:test-driven-development`, `@superpowers:systematic-debugging`, `@superpowers:verification-before-completion`.

---

### Task 1: Create Jean Proxy Core Module Skeleton

**Files:**
- Create: `jean/src-tauri/src/lib.rs`
- Create: `jean/src-tauri/src/app_state.rs`
- Create: `jean/src-tauri/src/proxy/mod.rs`
- Create: `jean/src-tauri/src/commands/mod.rs`
- Test: `jean/src-tauri/tests/app_state_bootstrap.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::app_state::AppState;

#[test]
fn app_state_starts_with_proxy_disabled() {
    let state = AppState::new_for_test();
    assert!(!state.runtime.proxy_enabled());
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test app_state_bootstrap`
Expected: FAIL with unresolved import/module errors.

**Step 3: Write minimal implementation**

```rust
pub mod app_state;

pub struct RuntimeState { enabled: bool }
impl RuntimeState {
    pub fn proxy_enabled(&self) -> bool { self.enabled }
}

pub struct AppState { pub runtime: RuntimeState }
impl AppState {
    pub fn new_for_test() -> Self {
        Self { runtime: RuntimeState { enabled: false } }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test app_state_bootstrap`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/lib.rs jean/src-tauri/src/app_state.rs jean/src-tauri/src/proxy/mod.rs jean/src-tauri/src/commands/mod.rs jean/src-tauri/tests/app_state_bootstrap.rs
git commit -m "chore: scaffold jean proxy core modules"
```

---

### Task 2: Implement Persistent Settings (Proxy Toggle, Autostart, Port Override)

**Files:**
- Create: `jean/src-tauri/src/settings.rs`
- Modify: `jean/src-tauri/src/app_state.rs`
- Test: `jean/src-tauri/tests/settings_persistence.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::settings::{AppSettings, SettingsStore};

#[test]
fn saves_and_loads_proxy_settings() {
    let dir = tempfile::tempdir().unwrap();
    let store = SettingsStore::new_for_path(dir.path().join("settings.json"));

    let expected = AppSettings {
        proxy_enabled: true,
        start_with_app: true,
        public_proxy_port: 8317,
        ..Default::default()
    };

    store.save(&expected).unwrap();
    let loaded = store.load().unwrap();
    assert_eq!(loaded.public_proxy_port, 8317);
    assert!(loaded.start_with_app);
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test settings_persistence`
Expected: FAIL with missing `settings` module/types.

**Step 3: Write minimal implementation**

```rust
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AppSettings {
    pub proxy_enabled: bool,
    pub start_with_app: bool,
    pub public_proxy_port: u16,
    pub backend_port: u16,
    pub enabled_providers: std::collections::BTreeMap<String, bool>,
    pub vercel_gateway_enabled: bool,
    pub vercel_api_key: String,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            proxy_enabled: false,
            start_with_app: false,
            public_proxy_port: 8317,
            backend_port: 8318,
            enabled_providers: BTreeMap::new(),
            vercel_gateway_enabled: false,
            vercel_api_key: String::new(),
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test settings_persistence`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/settings.rs jean/src-tauri/src/app_state.rs jean/src-tauri/tests/settings_persistence.rs
git commit -m "feat: add persistent settings for proxy runtime"
```

---

### Task 3: Add Sidecar Process Manager for `cli-proxy-api-plus`

**Files:**
- Create: `jean/src-tauri/src/process/sidecar_manager.rs`
- Modify: `jean/src-tauri/src/app_state.rs`
- Test: `jean/src-tauri/tests/sidecar_manager.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::process::sidecar_manager::SidecarManager;

#[tokio::test]
async fn start_sets_running_state() {
    let mgr = SidecarManager::new_for_test();
    mgr.mark_started_for_test();
    assert!(mgr.is_running().await);
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test sidecar_manager`
Expected: FAIL with missing process module.

**Step 3: Write minimal implementation**

```rust
pub struct SidecarManager { running: tokio::sync::RwLock<bool> }
impl SidecarManager {
    pub fn new_for_test() -> Self { Self { running: tokio::sync::RwLock::new(false) } }
    pub async fn is_running(&self) -> bool { *self.running.read().await }
    pub fn mark_started_for_test(&self) { futures::executor::block_on(async { *self.running.write().await = true; }); }
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test sidecar_manager`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/process/sidecar_manager.rs jean/src-tauri/src/app_state.rs jean/src-tauri/tests/sidecar_manager.rs
git commit -m "feat: add sidecar manager lifecycle state"
```

---

### Task 4: Implement Auth Filesystem Model (`~/.cli-proxy-api` parity)

**Files:**
- Create: `jean/src-tauri/src/auth/service_type.rs`
- Create: `jean/src-tauri/src/auth/account_store.rs`
- Test: `jean/src-tauri/tests/auth_account_store.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::auth::account_store::AccountStore;

#[test]
fn scans_active_and_disabled_accounts() {
    let dir = tempfile::tempdir().unwrap();
    let store = AccountStore::new_for_base(dir.path());
    store.seed_fixture_account("claude", "user@example.com");
    let snapshot = store.scan().unwrap();
    assert_eq!(snapshot.providers["claude"].active.len(), 1);
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test auth_account_store`
Expected: FAIL with missing auth store.

**Step 3: Write minimal implementation**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ServiceType { Claude, Codex, GithubCopilot, Gemini, Qwen, Antigravity, Zai }

pub struct AccountStore { base: PathBuf }
impl AccountStore {
    pub fn scan(&self) -> anyhow::Result<AccountSnapshot> { /* parse active/.disabled/.auto */ }
    pub fn disable_account(&self, filename: &str) -> anyhow::Result<()> { /* move to .disabled */ }
    pub fn auto_disable_account(&self, filename: &str) -> anyhow::Result<()> { /* move to .disabled/.auto */ }
    pub fn restore_account(&self, filename: &str) -> anyhow::Result<()> { /* move back to active */ }
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test auth_account_store`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/auth/service_type.rs jean/src-tauri/src/auth/account_store.rs jean/src-tauri/tests/auth_account_store.rs
git commit -m "feat: add cli-proxy auth account store parity"
```

---

### Task 5: Implement Provider Login Command Runner

**Files:**
- Create: `jean/src-tauri/src/auth/login_runner.rs`
- Modify: `jean/src-tauri/src/process/sidecar_manager.rs`
- Test: `jean/src-tauri/tests/login_runner_args.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::auth::login_runner::{AuthCommand, build_args};

#[test]
fn maps_provider_to_cli_proxy_flags() {
    assert_eq!(build_args(AuthCommand::ClaudeLogin, "config.yaml"), vec!["--config", "config.yaml", "-claude-login"]);
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test login_runner_args`
Expected: FAIL with missing auth runner.

**Step 3: Write minimal implementation**

```rust
pub enum AuthCommand {
    ClaudeLogin,
    CodexLogin,
    CopilotLogin,
    GeminiLogin,
    QwenLogin { email: String },
    AntigravityLogin,
    ZaiApiKey { api_key: String },
}

pub fn build_args(cmd: AuthCommand, config: &str) -> Vec<&str> { /* exact flag mapping */ }
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test login_runner_args`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/auth/login_runner.rs jean/src-tauri/src/process/sidecar_manager.rs jean/src-tauri/tests/login_runner_args.rs
git commit -m "feat: add provider auth command runner"
```

---

### Task 6: Implement Merged Config Builder (Provider Exclusion + Z.AI)

**Files:**
- Create: `jean/src-tauri/src/config/merged_config.rs`
- Test: `jean/src-tauri/tests/merged_config.rs`
- Modify: `jean/src-tauri/src/process/sidecar_manager.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::config::merged_config::build_merged_config;

#[test]
fn injects_oauth_excluded_models_and_zai_entries() {
    let merged = build_merged_config(
        "port: 8318\n",
        &["claude".into()],
        &["zai-key-123".into()],
        true,
    );
    assert!(merged.contains("oauth-excluded-models"));
    assert!(merged.contains("openai-compatibility"));
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test merged_config`
Expected: FAIL with missing config builder.

**Step 3: Write minimal implementation**

```rust
pub fn build_merged_config(base_yaml: &str, disabled: &[String], zai_keys: &[String], zai_enabled: bool) -> String {
    // append oauth-excluded-models and optional zai openai-compatibility block
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test merged_config`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/config/merged_config.rs jean/src-tauri/src/process/sidecar_manager.rs jean/src-tauri/tests/merged_config.rs
git commit -m "feat: add merged cli-proxy config generation"
```

---

### Task 7: Implement Edge Proxy Core (Pass-through + Diagnostics Endpoints)

**Files:**
- Create: `jean/src-tauri/src/proxy/server.rs`
- Create: `jean/src-tauri/src/proxy/diagnostics.rs`
- Test: `jean/src-tauri/tests/proxy_diagnostics.rs`

**Step 1: Write the failing test**

```rust
#[tokio::test]
async fn usage_reset_endpoint_returns_ok() {
    let app = jean_ice::proxy::server::build_test_router();
    let res = app.oneshot(http::Request::post("/vibe/usage/reset").body(axum::body::Body::empty()).unwrap()).await.unwrap();
    assert_eq!(res.status(), http::StatusCode::OK);
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test proxy_diagnostics`
Expected: FAIL with missing proxy router.

**Step 3: Write minimal implementation**

```rust
pub fn build_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/vibe/status", get(status_handler))
        .route("/vibe/usage", get(usage_handler))
        .route("/vibe/usage/reset", post(reset_usage_handler))
        .fallback(any(forward_handler))
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test proxy_diagnostics`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/proxy/server.rs jean/src-tauri/src/proxy/diagnostics.rs jean/src-tauri/tests/proxy_diagnostics.rs
git commit -m "feat: add edge proxy server with diagnostics endpoints"
```

---

### Task 8: Implement API Compatibility and Amp Routing Rules

**Files:**
- Create: `jean/src-tauri/src/proxy/path_rewrite.rs`
- Modify: `jean/src-tauri/src/proxy/server.rs`
- Test: `jean/src-tauri/tests/path_rewrite.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::proxy::path_rewrite::rewrite_path;

#[test]
fn rewrites_amp_provider_paths() {
    assert_eq!(rewrite_path("/provider/openai/chat"), "/api/provider/openai/chat");
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test path_rewrite`
Expected: FAIL with missing rewrite module.

**Step 3: Write minimal implementation**

```rust
pub fn rewrite_path(path: &str) -> String {
    if path.starts_with("/provider/") { return format!("/api{}", path); }
    path.to_string()
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test path_rewrite`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/proxy/path_rewrite.rs jean/src-tauri/src/proxy/server.rs jean/src-tauri/tests/path_rewrite.rs
git commit -m "feat: add amp and v1 path compatibility rewrites"
```

---

### Task 9: Implement Thinking and Reasoning Model Transforms

**Files:**
- Create: `jean/src-tauri/src/proxy/model_transform.rs`
- Modify: `jean/src-tauri/src/proxy/server.rs`
- Test: `jean/src-tauri/tests/model_transform.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::proxy::model_transform::apply_transforms;

#[test]
fn adds_reasoning_effort_for_reasoning_suffix() {
    let body = r#"{"model":"gpt-5.1-reasoning-high"}"#;
    let out = apply_transforms(body).unwrap();
    assert!(out.contains("\"reasoning\":{\"effort\":\"high\"}"));
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test model_transform`
Expected: FAIL with missing transform module.

**Step 3: Write minimal implementation**

```rust
pub struct TransformResult { pub body: String, pub thinking_enabled: bool }

pub fn apply_transforms(body: &str) -> anyhow::Result<TransformResult> {
    // 1) claude/gemini-claude -thinking-* => inject thinking + token headroom
    // 2) non-claude -reasoning-* => inject reasoning.effort
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test model_transform`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/proxy/model_transform.rs jean/src-tauri/src/proxy/server.rs jean/src-tauri/tests/model_transform.rs
git commit -m "feat: add thinking and reasoning compatibility transforms"
```

---

### Task 10: Implement Qualified Model IDs and Provider-Pinned Routing

**Files:**
- Create: `jean/src-tauri/src/proxy/qualified_model.rs`
- Modify: `jean/src-tauri/src/proxy/server.rs`
- Test: `jean/src-tauri/tests/qualified_model_routing.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::proxy::qualified_model::resolve_qualified_model;

#[test]
fn provider_prefixed_model_rewrites_path_and_model() {
    let body = r#"{"model":"github-copilot/claude-sonnet-4-5"}"#;
    let resolved = resolve_qualified_model("/v1/chat/completions", body).unwrap();
    assert_eq!(resolved.forward_path, "/api/provider/github-copilot/v1/chat/completions");
    assert!(resolved.forward_body.contains("\"model\":\"claude-sonnet-4-5\""));
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test qualified_model_routing`
Expected: FAIL with missing qualified model module.

**Step 3: Write minimal implementation**

```rust
pub struct QualifiedRouting {
    pub forward_path: String,
    pub forward_body: String,
    pub provider: Option<String>,
    pub model_id: String,
}

pub fn resolve_qualified_model(path: &str, body: &str) -> anyhow::Result<QualifiedRouting> {
    // if model contains provider/model_id:
    // - set provider hint
    // - rewrite model to model_id
    // - forward to /api/provider/{provider}{path}
    // else pass through unchanged
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test qualified_model_routing`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/proxy/qualified_model.rs jean/src-tauri/src/proxy/server.rs jean/src-tauri/tests/qualified_model_routing.rs
git commit -m "feat: enforce provider-pinned routing for qualified model ids"
```

---

### Task 11: Implement Model Groups (Manual Groups, Round-Robin, Failover, `/v1/models` Injection)

**Files:**
- Create: `jean/src-tauri/src/model_groups/group_store.rs`
- Create: `jean/src-tauri/src/model_groups/router.rs`
- Modify: `jean/src-tauri/src/proxy/server.rs`
- Test: `jean/src-tauri/tests/model_group_router.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::model_groups::router::{ModelGroup, ModelGroupRouter};

#[test]
fn round_robin_and_failover_behaves_as_expected() {
    let mut router = ModelGroupRouter::default();
    router.update(vec![ModelGroup::new("coding-fast", vec!["openai/gpt-5", "github-copilot/claude-sonnet-4-5"])]);

    let first = router.resolve("coding-fast").unwrap();
    let second = router.resolve("coding-fast").unwrap();
    assert_ne!(first.real_model, second.real_model);
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test model_group_router`
Expected: FAIL with missing model_groups module.

**Step 3: Write minimal implementation**

```rust
#[derive(Clone, Serialize, Deserialize)]
pub struct ModelGroup { pub id: Uuid, pub name: String, pub models: Vec<String>, pub enabled: bool }

pub struct ModelGroupRouter { groups: Vec<ModelGroup>, counters: HashMap<Uuid, usize> }
impl ModelGroupRouter {
    pub fn resolve(&mut self, name: &str) -> Option<ResolvedGroupModel> { /* round-robin */ }
    pub fn failover_next(&self, group_id: Uuid, tried: &HashSet<String>) -> Option<String> { /* retry candidate */ }
    pub fn inject_models_response(&self, data: serde_json::Value) -> serde_json::Value { /* add virtual models */ }
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test model_group_router`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/model_groups/group_store.rs jean/src-tauri/src/model_groups/router.rs jean/src-tauri/src/proxy/server.rs jean/src-tauri/tests/model_group_router.rs
git commit -m "feat: add model groups with rr failover and models injection"
```

---

### Task 12: Implement Diagnostics Usage Tracking and Next-Account Rotation

**Files:**
- Create: `jean/src-tauri/src/proxy/usage_stats.rs`
- Modify: `jean/src-tauri/src/proxy/diagnostics.rs`
- Test: `jean/src-tauri/tests/usage_rotation.rs`

**Step 1: Write the failing test**

```rust
use jean_ice::proxy::usage_stats::UsageStats;

#[test]
fn computes_next_account_rotation_from_provider_counts() {
    let mut stats = UsageStats::default();
    stats.bump_provider("claude");
    let next = stats.next_account_index("claude", 3);
    assert_eq!(next, 1);
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test usage_rotation`
Expected: FAIL with missing usage stats module.

**Step 3: Write minimal implementation**

```rust
#[derive(Default)]
pub struct UsageStats {
    pub total_requests: u64,
    pub endpoint_counts: HashMap<String, u64>,
    pub provider_counts: HashMap<String, u64>,
    pub model_counts: HashMap<String, u64>,
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test usage_rotation`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/proxy/usage_stats.rs jean/src-tauri/src/proxy/diagnostics.rs jean/src-tauri/tests/usage_rotation.rs
git commit -m "feat: add diagnostics usage counters and rotation tracking"
```

---

### Task 13: Implement Claude/Codex Usage Pollers + Auto-disable/Restore

**Files:**
- Create: `jean/src-tauri/src/usage/claude_usage.rs`
- Create: `jean/src-tauri/src/usage/codex_usage.rs`
- Create: `jean/src-tauri/src/usage/auto_disable.rs`
- Test: `jean/src-tauri/tests/provider_usage_polling.rs`

**Step 1: Write the failing test**

```rust
#[tokio::test]
async fn marks_account_auto_disabled_when_remaining_is_zero() {
    let result = jean_ice::usage::auto_disable::should_auto_disable(0);
    assert!(result);
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test provider_usage_polling`
Expected: FAIL with missing usage modules.

**Step 3: Write minimal implementation**

```rust
pub fn should_auto_disable(primary_remaining_percent: i32) -> bool {
    primary_remaining_percent <= 0
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test provider_usage_polling`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/usage/claude_usage.rs jean/src-tauri/src/usage/codex_usage.rs jean/src-tauri/src/usage/auto_disable.rs jean/src-tauri/tests/provider_usage_polling.rs
git commit -m "feat: add provider usage polling and auto-disable rules"
```

---

### Task 14: Expose Tauri Commands for UI Integration

**Files:**
- Create: `jean/src-tauri/src/commands/proxy.rs`
- Create: `jean/src-tauri/src/commands/accounts.rs`
- Create: `jean/src-tauri/src/commands/model_groups.rs`
- Modify: `jean/src-tauri/src/main.rs`
- Test: `jean/src-tauri/tests/commands_smoke.rs`

**Step 1: Write the failing test**

```rust
#[tokio::test]
async fn toggle_proxy_command_updates_runtime_state() {
    let state = jean_ice::app_state::AppState::new_for_test();
    jean_ice::commands::proxy::set_proxy_enabled(tauri::State::from(&state), true).await.unwrap();
    assert!(state.runtime.proxy_enabled());
}
```

**Step 2: Run test to verify it fails**

Run: `cd jean/src-tauri && cargo test --test commands_smoke`
Expected: FAIL with missing command handlers.

**Step 3: Write minimal implementation**

```rust
#[tauri::command]
pub async fn set_proxy_enabled(state: State<'_, AppState>, enabled: bool) -> Result<(), String> {
    state.runtime.set_proxy_enabled(enabled).await.map_err(|e| e.to_string())
}
```

**Step 4: Run test to verify it passes**

Run: `cd jean/src-tauri && cargo test --test commands_smoke`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/src/commands/proxy.rs jean/src-tauri/src/commands/accounts.rs jean/src-tauri/src/commands/model_groups.rs jean/src-tauri/src/main.rs jean/src-tauri/tests/commands_smoke.rs
git commit -m "feat: expose tauri command surface for jean ui"
```

---

### Task 15: Implement Frontend Parity Screens and Interaction Flows

**Files:**
- Create: `jean/src/features/settings/ProxySettingsPanel.tsx`
- Create: `jean/src/features/accounts/ProviderAccountsPanel.tsx`
- Create: `jean/src/features/model-groups/ModelGroupsPanel.tsx`
- Create: `jean/src/features/usage/UsagePanel.tsx`
- Create: `jean/src/lib/api/client.ts`
- Test: `jean/src/features/settings/__tests__/ProxySettingsPanel.test.tsx`
- Test: `jean/tests/e2e/parity-smoke.spec.ts`

**Step 1: Write the failing test**

```tsx
import { render, screen } from "@testing-library/react";
import { ProxySettingsPanel } from "../ProxySettingsPanel";

test("renders proxy toggle and port field", () => {
  render(<ProxySettingsPanel />);
  expect(screen.getByLabelText(/Proxy enabled/i)).toBeInTheDocument();
  expect(screen.getByLabelText(/Public proxy port/i)).toBeInTheDocument();
});
```

**Step 2: Run test to verify it fails**

Run: `cd jean && pnpm vitest src/features/settings/__tests__/ProxySettingsPanel.test.tsx --run`
Expected: FAIL with missing component.

**Step 3: Write minimal implementation**

```tsx
export function ProxySettingsPanel() {
  return (
    <section>
      <label>Proxy enabled<input aria-label="Proxy enabled" type="checkbox" /></label>
      <label>Public proxy port<input aria-label="Public proxy port" type="number" /></label>
    </section>
  );
}
```

**Step 4: Run tests to verify they pass**

Run: `cd jean && pnpm vitest src/features/settings/__tests__/ProxySettingsPanel.test.tsx --run`
Expected: PASS.

Run: `cd jean && pnpm playwright test tests/e2e/parity-smoke.spec.ts`
Expected: PASS for startup, provider linking stub, and model group flow smoke checks.

**Step 5: Commit**

```bash
git add jean/src/features/settings/ProxySettingsPanel.tsx jean/src/features/accounts/ProviderAccountsPanel.tsx jean/src/features/model-groups/ModelGroupsPanel.tsx jean/src/features/usage/UsagePanel.tsx jean/src/lib/api/client.ts jean/src/features/settings/__tests__/ProxySettingsPanel.test.tsx jean/tests/e2e/parity-smoke.spec.ts
git commit -m "feat: add jean parity ui panels and smoke tests"
```

---

### Task 16: Cross-Platform Packaging, Autostart, and Release Verification

**Files:**
- Modify: `jean/src-tauri/tauri.conf.json`
- Modify: `jean/src-tauri/Cargo.toml`
- Create: `jean/scripts/verify-parity.sh`
- Create: `jean/docs/compatibility/parity-checklist.md`
- Create: `jean/docs/compatibility/provider-routing-matrix.md`

**Step 1: Write the failing verification script check**

```bash
#!/usr/bin/env bash
set -euo pipefail
curl -fsS http://127.0.0.1:8317/vibe/status >/dev/null
curl -fsS http://127.0.0.1:8317/vibe/usage >/dev/null
```

**Step 2: Run verification to show missing behavior**

Run: `cd jean && bash scripts/verify-parity.sh`
Expected: FAIL before final wiring.

**Step 3: Implement packaging + autostart configuration**

```json
{
  "bundle": { "externalBin": ["binaries/cli-proxy-api-plus"] },
  "plugins": { "autostart": { "enabled": true } }
}
```

**Step 4: Run full verification**

Run: `cd jean/src-tauri && cargo test`
Expected: PASS.

Run: `cd jean && pnpm test && bash scripts/verify-parity.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add jean/src-tauri/tauri.conf.json jean/src-tauri/Cargo.toml jean/scripts/verify-parity.sh jean/docs/compatibility/parity-checklist.md jean/docs/compatibility/provider-routing-matrix.md
git commit -m "chore: finalize cross-platform packaging and parity verification"
```

---

## Final Release Gate (must be manually checked)

1. Proxy toggle starts/stops edge + sidecar cleanly on macOS, Windows, Linux.
2. Start-with-app works on all three platforms.
3. Public proxy port override persists and binds correctly.
4. All provider login flows complete and write valid auth files.
5. Qualified model IDs pin provider routing correctly.
6. Model groups rotate and fail over correctly on retryable statuses.
7. `/v1/models` includes real + virtual models.
8. Thinking/reasoning transforms are reflected in forwarded payloads.
9. `/vibe/status`, `/vibe/usage`, `/vibe/usage/reset` match compatibility contract.
10. Claude/Codex usage polling and auto-disable/restore behavior matches the expected UX.
