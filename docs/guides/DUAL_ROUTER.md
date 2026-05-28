# Dual-Router Implementation Plan: Arch-Router + MIRT-BERT

**Status:** Planning Phase
**Timeline:** 4-5 weeks
**Architecture:** Arch-Router (task classification) + MIRT-BERT (cost-quality prediction)
**Executor Integration:** Candidates from ServiceDiscoveryManager + Auggie/Cursor/other CLIs

---

## 1. System Overview

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                    Vibeproxy (Swift)                              │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │ Policy Editor UI                                          │   │
│  │ - Define: domain-action → candidate model list            │   │
│  │ - Example: "programming/code-gen" → [gpt-4, claude, gemini] │   │
│  │ - Upload MIRT training data (historical perf logs)        │   │
│  │ - Monitor: accuracy, cost reduction, routing decisions    │   │
│  └───────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
    ↓ (gRPC/HTTP)
┌──────────────────────────────────────────────────────────────────┐
│              CLIProxyAPI (Go)                                     │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  DualRouter Orchestrator (~500 LOC)                       │   │
│  │                                                            │   │
│  │  Step 1: Arch-Router Classification (50ms)               │   │
│  │  ├─ Input: User prompt + conversation context            │   │
│  │  ├─ Output: domain + action (e.g., "programming"/"bug-fix") │   │
│  │  └─ Via MLX-LM Server: Arch-Router 1.5B inference         │   │
│  │                                                            │   │
│  │  Step 2: Candidate Pool Generation                       │   │
│  │  ├─ Query PolicyDB: domain-action → model list          │   │
│  │  ├─ Merge with executor models:                         │   │
│  │  │  ├─ ServiceDiscoveryManager: api-based models         │   │
│  │  │  ├─ Auggie CLI: auggie service                        │   │
│  │  │  ├─ Cursor Agent: cursor service                      │   │
│  │  │  └─ Other executors: copilot, etc.                    │   │
│  │  └─ Final candidates: [model1, model2, model3, ...]      │   │
│  │                                                            │   │
│  │  Step 3: MIRT-BERT Cost-Quality Prediction (15-30ms)     │   │
│  │  ├─ For each candidate model:                            │   │
│  │  │  ├─ Query difficulty: extract features from prompt    │   │
│  │  │  ├─ Model ability: 25D latent vector (trained)        │   │
│  │  │  ├─ P(success) = sigmoid(Σ a_i · (θ_i - b_i))        │   │
│  │  │  └─ Score = P(success) / (cost_per_mtok)              │   │
│  │  └─ Result: ranked [model1: 0.92, model2: 0.85, ...]     │   │
│  │                                                            │   │
│  │  Step 4: Final Selection                                 │   │
│  │  └─ Select model with highest weighted score             │   │
│  │                                                            │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                    │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  Supporting Systems                                        │   │
│  │  ├─ PostgreSQL: policies, training data, executor metadata │   │
│  │  ├─ ModelRegistry: executor services + their capabilities │   │
│  │  ├─ FeatureExtractor: prompt → difficulty features         │   │
│  │  └─ MetricsTracker: log decisions for MIRT retraining    │   │
│  └───────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
    ├─→ MLX-LM Server (Python, local Mac inference)
    │   └─→ Arch-Router 1.5B (Qwen 2.5 fine-tuned)
    │       └─ 50ms latency, 93.17% accuracy
    │
    ├─→ Bifrost Gateway (Go)
    │   ├─→ OpenAI (GPT-4, GPT-3.5-turbo, etc.)
    │   ├─→ Anthropic (Claude 3.7, etc.)
    │   ├─→ Google Vertex (Gemini, etc.)
    │   └─→ Other providers
    │
    └─→ Executor Services (Dynamic)
        ├─→ Auggie CLI (auggie service model)
        ├─→ Cursor Agent (cursor-agent binary)
        └─→ Other CLIs discovered via ServiceDiscoveryManager
```

### Data Flow

```
User Request (Chat message)
    ↓
Arch-Router (MLX-LM Server)
    ├─ Classify: domain + action
    └─ Output: "programming/code-generation"
    ↓
PolicyDB Lookup
    ├─ Query: SELECT models WHERE domain='programming' AND action='code-generation'
    └─ Output: policy_models = [gpt-4, claude, codex, auggie]
    ↓
Executor Discovery
    ├─ ServiceDiscoveryManager: [gpt-4, claude, codex, gemini]
    ├─ Auggie Service: auggie (if available)
    ├─ Cursor Service: cursor (if available)
    └─ Merged candidates: [gpt-4, claude, codex, gemini, auggie, cursor]
    ↓
Candidate Pool Filter
    ├─ Intersect: policy_models ∩ available_models
    ├─ Result: [gpt-4, claude, codex, auggie]
    └─ Cost filter: remove models over budget if needed
    ↓
MIRT-BERT Prediction
    ├─ For each candidate:
    │  ├─ Extract features: complexity, domain, task type, token est.
    │  ├─ Load model ability (25D vector from checkpoint)
    │  ├─ Compute P(success) using IRT formula
    │  ├─ Apply cost weighting: score / (cost_per_mtok + overhead)
    │  └─ Log: {prompt, candidate, features, prediction, actual_perf}
    └─ Output: ranked scores
    ↓
Selection
    ├─ Best = argmax(scores)
    ├─ Fallback chain: if best fails → try 2nd best, etc.
    └─ Route to selected model
    ↓
Outcome Tracking
    ├─ Record actual performance metrics
    ├─ Feed back to MetricsTracker for MIRT retraining
    └─ Update executor model registry if needed
```

---

## 2. Core Components

### 2.1 DualRouter (Go, ~500 LOC)

**File:** `internal/routing/dual_router.go`

**Key Types:**

```go
type DualRouter struct {
    archRouter          *ArchRouter         // Arch-Router 1.5B client
    mirtRouter          *MIRTRouter         // MIRT-BERT inference
    policyDB            *sql.DB             // domain-action → models
    executorRegistry    *ExecutorRegistry   // Auggie, Cursor, etc.
    featureExtractor    *FeatureExtractor   // Prompt → difficulty
    metricsTracker      *MetricsTracker     // Log for MIRT retraining
}

type ArchClassification struct {
    Domain      string  `json:"domain"`      // e.g., "programming"
    Action      string  `json:"action"`      // e.g., "code-generation"
    Confidence  float32 `json:"confidence"`
    Reasoning   string  `json:"reasoning"`
}

type MIRTScore struct {
    ModelID           string
    SuccessProbability float32
    CostPerMToken     float32
    WeightedScore     float32  // P(success) / cost
    Explanation       string
}

type RoutingDecision struct {
    SelectedModel       string
    Candidates          []*MIRTScore
    ArchClassification  *ArchClassification
    TotalLatency        time.Duration
    Confidence          float32
    Reasoning           string
}
```

**Main Method:**

```go
func (dr *DualRouter) Route(ctx context.Context, prompt string) (*RoutingDecision, error) {
    start := time.Now()

    // Step 1: Classify with Arch-Router
    archClass, err := dr.classifyWithArch(ctx, prompt)
    if err != nil {
        return nil, fmt.Errorf("arch classification failed: %w", err)
    }

    // Step 2: Get policy-based candidates
    policyCandidates, err := dr.getPolicyCandidates(ctx, archClass.Domain, archClass.Action)
    if err != nil {
        return nil, fmt.Errorf("policy lookup failed: %w", err)
    }

    // Step 3: Get available executor models
    executorModels, err := dr.getExecutorModels(ctx)
    if err != nil {
        return nil, fmt.Errorf("executor discovery failed: %w", err)
    }

    // Step 4: Merge and filter candidates
    finalCandidates := dr.mergeCandidates(policyCandidates, executorModels)

    // Step 5: Score with MIRT-BERT
    scores, err := dr.scoreWithMIRT(ctx, prompt, finalCandidates)
    if err != nil {
        return nil, fmt.Errorf("mirt scoring failed: %w", err)
    }

    // Step 6: Select best
    best := dr.selectBest(scores)

    // Step 7: Log for metrics/retraining
    dr.metricsTracker.Log(MetricRecord{
        Prompt:     prompt,
        Domain:     archClass.Domain,
        Action:     archClass.Action,
        Candidates: finalCandidates,
        Scores:     scores,
        Selected:   best.ModelID,
    })

    return &RoutingDecision{
        SelectedModel:      best.ModelID,
        Candidates:         scores,
        ArchClassification: archClass,
        TotalLatency:       time.Since(start),
        Confidence:         best.WeightedScore,
        Reasoning: fmt.Sprintf(
            "Arch: %s/%s (%s) → Candidates: %v → MIRT: %s (%.2f success, %.3f cost-adjusted)",
            archClass.Domain, archClass.Action, archClass.Reasoning,
            candidateIDs(finalCandidates),
            best.ModelID, best.SuccessProbability,
        ),
    }, nil
}
```

### 2.2 ExecutorRegistry (Go, ~300 LOC)

**File:** `internal/executors/registry.go`

**Purpose:** Unified view of all available models from different sources

```go
type ExecutorRegistry struct {
    // API-based services (via ServiceDiscoveryManager)
    apiModels map[string]*Model

    // Auggie CLI service
    auggieService *ExecutorService

    // Cursor Agent service
    cursorService *ExecutorService

    // Other executors
    otherExecutors map[string]*ExecutorService
}

type ExecutorService struct {
    ID              string        // "auggie", "cursor", etc.
    Type            ExecutorType  // CLI, HTTP, gRPC
    AvailableModels []*Model
    HealthStatus    HealthStatus
    Capabilities    []string      // ["code-gen", "analysis", etc.]
}

type Model struct {
    ID                string
    Source            string        // "auggie", "openai", "anthropic", etc.
    DisplayName       string
    CostPerMToken     float32
    AvailableContext  int
    Capabilities      []string
    Tier              string        // "premium", "budget", "free"
    IsHealthy         bool
    LastHealthCheck   time.Time
}

// Get all available models across all executors
func (er *ExecutorRegistry) GetAllModels(ctx context.Context) ([]*Model, error) {
    var models []*Model

    // From API services (ServiceDiscoveryManager)
    for _, m := range er.apiModels {
        if m.IsHealthy {
            models = append(models, m)
        }
    }

    // From Auggie CLI
    if er.auggieService.IsHealthy() {
        auggieModels, err := er.auggieService.ListModels(ctx)
        if err == nil {
            models = append(models, auggieModels...)
        }
    }

    // From Cursor Agent
    if er.cursorService.IsHealthy() {
        cursorModels, err := er.cursorService.ListModels(ctx)
        if err == nil {
            models = append(models, cursorModels...)
        }
    }

    // From other executors
    for _, svc := range er.otherExecutors {
        if svc.IsHealthy() {
            svcModels, err := svc.ListModels(ctx)
            if err == nil {
                models = append(models, svcModels...)
            }
        }
    }

    return models, nil
}

// Get models by executor type
func (er *ExecutorRegistry) GetModelsBySource(ctx context.Context, source string) ([]*Model, error) {
    switch source {
    case "openai", "anthropic", "google", "cerebras":
        return []*Model{er.apiModels[source]}, nil
    case "auggie":
        return er.auggieService.ListModels(ctx)
    case "cursor":
        return er.cursorService.ListModels(ctx)
    default:
        if svc, ok := er.otherExecutors[source]; ok {
            return svc.ListModels(ctx)
        }
    }
    return nil, fmt.Errorf("unknown source: %s", source)
}
```

### 2.3 PolicyDB Schema (SQL/PostgreSQL)

**File:** `migrations/xxx_create_routing_policies.sql`

```sql
-- Store domain-action → model mappings
CREATE TABLE routing_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain VARCHAR(100) NOT NULL,
    action VARCHAR(100) NOT NULL,
    model_ids TEXT[] NOT NULL,  -- JSON array of model IDs
    priority INT DEFAULT 0,     -- Higher = prefer this policy
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(domain, action),
    INDEX idx_domain_action (domain, action)
);

-- Store candidate models for quick lookup
CREATE TABLE candidate_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID NOT NULL REFERENCES routing_policies(id) ON DELETE CASCADE,
    model_id VARCHAR(100) NOT NULL,
    rank INT NOT NULL,          -- Order preference: 1, 2, 3...
    min_context_tokens INT,     -- Min context this policy needs
    tags VARCHAR(100)[],        -- e.g., ["fast", "cheap", "reasoning"]

    UNIQUE(policy_id, model_id)
);

-- Store executor metadata
CREATE TABLE executor_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,  -- "auggie", "cursor", "openai", etc.
    type VARCHAR(50) NOT NULL,          -- "cli", "http", "grpc"
    endpoint VARCHAR(500),              -- URL or CLI path
    health_status VARCHAR(50) DEFAULT 'unknown',
    last_health_check TIMESTAMP,
    config JSONB,                       -- Service-specific config

    INDEX idx_name (name)
);

-- Log routing decisions for metrics/retraining
CREATE TABLE routing_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prompt TEXT NOT NULL,
    domain VARCHAR(100),
    action VARCHAR(100),
    candidates TEXT[],                  -- Model IDs considered
    arch_confidence FLOAT,              -- Arch-Router confidence
    mirt_scores JSONB,                  -- {model_id: score, ...}
    selected_model VARCHAR(100) NOT NULL,
    selected_score FLOAT,
    actual_performance FLOAT,           -- 0-1: how well it did
    cost_actual FLOAT,                  -- Actual tokens consumed
    latency_ms INT,
    created_at TIMESTAMP DEFAULT NOW(),

    INDEX idx_selected (selected_model),
    INDEX idx_domain_action (domain, action)
);

-- Store MIRT-BERT model checkpoint metadata
CREATE TABLE mirt_checkpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version VARCHAR(50) NOT NULL UNIQUE,
    checkpoint_path VARCHAR(500) NOT NULL,
    trained_on INT,                     -- # of examples
    val_accuracy FLOAT,
    val_auc FLOAT,
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT FALSE,    -- Currently in use

    INDEX idx_active (is_active)
);
```

### 2.4 FeatureExtractor (Go, ~200 LOC)

**File:** `internal/routing/feature_extractor.go`

**Purpose:** Extract difficulty features from prompts for MIRT scoring

```go
type QueryFeatures struct {
    Length              int       // Token count
    Complexity          float32   // 0-1: estimated complexity
    HasCode             bool      // Contains code snippets
    CodeLines           int       // Approx lines of code
    DomainIndicators    []string  // Keywords indicating domain
    ToolCallRequired    bool      // Needs tool use
    EstimatedTokens     int       // Input tokens estimate
    ConversationDepth   int       // # of turns
    AmbiguityLevel      float32   // 0-1: unclear intent?
}

func (fe *FeatureExtractor) Extract(prompt string) (*QueryFeatures, error) {
    // Tokenize
    tokens := fe.tokenizer.Encode(prompt)

    // Basic features
    features := &QueryFeatures{
        Length:  len(tokens),
        HasCode: detectCode(prompt),
    }

    // Complexity heuristics
    features.Complexity = computeComplexity(prompt)
    features.CodeLines = countCodeLines(prompt)
    features.DomainIndicators = extractDomains(prompt)
    features.ToolCallRequired = needsToolCall(prompt)
    features.EstimatedTokens = estimateTokens(len(tokens))
    features.ConversationDepth = extractConversationDepth(prompt)
    features.AmbiguityLevel = computeAmbiguity(prompt)

    return features, nil
}
```

### 2.5 MIRT Inference (Go wrapper, ~150 LOC)

**File:** `internal/routing/mirt_client.go`

**Purpose:** Load MIRT checkpoint and score prompts

```go
type MIRTRouter struct {
    checkpoint      *Checkpoint          // Loaded from disk
    featureExtractor *FeatureExtractor
    modelAbilities  map[string][]float32 // 25D ability vectors per model
}

func (mr *MIRTRouter) Score(
    ctx context.Context,
    features *QueryFeatures,
    candidates []*Model,
) (map[string]float32, error) {
    scores := make(map[string]float32)

    for _, model := range candidates {
        // Get model ability vector (25D)
        ability, ok := mr.modelAbilities[model.ID]
        if !ok {
            // Fallback: use semantic similarity to find closest model
            ability = mr.findClosestAbility(model.ID)
        }

        // Compute difficulty (b parameters)
        difficulty := mr.computeDifficulty(features)

        // IRT formula: P(success) = sigmoid(Σ a_i * (θ_i - b_i))
        logit := 0.0
        for i := 0; i < len(ability); i++ {
            if i < len(difficulty) {
                logit += float64(ability[i]) * float64(ability[i]-difficulty[i])
            }
        }

        // Sigmoid
        successProb := 1.0 / (1.0 + math.Exp(-logit))

        // Cost adjustment
        costFactor := 1.0 + float64(model.CostPerMToken)*10.0
        score := float32(successProb / costFactor)

        scores[model.ID] = score
    }

    return scores, nil
}
```

---

## 3. Integration Points

### 3.1 Vibeproxy → CLIProxyAPI

```swift
// SettingsView.swift additions

struct RoutingPolicyEditor: View {
    @State var policies: [RoutingPolicy] = []
    @State var executorModels: [Model] = []

    var body: some View {
        VStack {
            // Policy definitions
            List {
                ForEach(policies) { policy in
                    PolicyRow(policy: policy)
                }
                .onDelete { indices in deletePolicy(at: indices) }
            }

            // Executor status
            VStack(alignment: .leading) {
                Text("Available Executors").font(.headline)
                ForEach(executorModels, id: \.id) { model in
                    HStack {
                        Image(systemName: model.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(model.isHealthy ? .green : .red)
                        Text(model.displayName)
                        Spacer()
                        Text("$\(String(format: "%.4f", model.costPerMToken))/MT")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            CLIProxyAPI.shared.getRoutingPolicies { policies in
                self.policies = policies
            }
            CLIProxyAPI.shared.getExecutorModels { models in
                self.executorModels = models
            }
        }
    }
}

struct RoutingPolicy: Identifiable {
    let id: UUID
    let domain: String
    let action: String
    var preferredModels: [String]
}
```

### 3.2 CLIProxyAPI Endpoints

```go
// In api/routes/routing.go

func GetRoutingPolicies(c *gin.Context) {
    policies, err := db.GetAllPolicies(c.Request.Context())
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }
    c.JSON(200, policies)
}

func CreateRoutingPolicy(c *gin.Context) {
    var req struct {
        Domain         string   `json:"domain" binding:"required"`
        Action         string   `json:"action" binding:"required"`
        PreferredModels []string `json:"preferred_models" binding:"required"`
    }

    if err := c.BindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }

    policy := &RoutingPolicy{
        Domain: req.Domain,
        Action: req.Action,
        Models: req.PreferredModels,
    }

    if err := db.CreatePolicy(c.Request.Context(), policy); err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    c.JSON(201, policy)
}

func GetExecutorModels(c *gin.Context) {
    models, err := executorRegistry.GetAllModels(c.Request.Context())
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }
    c.JSON(200, models)
}

func RouteRequest(c *gin.Context) {
    var req struct {
        Prompt string `json:"prompt" binding:"required"`
    }

    if err := c.BindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }

    decision, err := dualRouter.Route(c.Request.Context(), req.Prompt)
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    c.JSON(200, decision)
}
```

### 3.3 MLX-LM Server Integration

```bash
# Start MLX server before CLIProxyAPI
python -m mlx_lm.server \
    --model katanemo/Arch-Router-1.5B \
    --host 127.0.0.1 \
    --port 8008
```

**In Go (arch_router.go):**

```go
type ArchRouter struct {
    client *http.Client
    baseURL string  // "http://localhost:8008"
}

func (ar *ArchRouter) Classify(ctx context.Context, prompt string) (*ArchClassification, error) {
    // Build routes from policy DB
    routes := ar.buildRoutes(ctx)

    // Call MLX server
    resp, err := ar.client.Post(
        ar.baseURL + "/v1/chat/completions",
        "application/json",
        buildRequestBody(prompt, routes),
    )

    // Parse response
    return ar.parseResponse(resp)
}
```

---

## 4. Weekly Breakdown

### Week 1: Foundation & Setup

**Days 1-2: MLX-LM + Arch-Router Local Setup**
- [ ] Install MLX dependencies: `pip install mlx mlx-lm`
- [ ] Download Arch-Router model: `huggingface-cli download katanemo/Arch-Router-1.5B`
- [ ] Start MLX server and verify responses
- [ ] Test prompt formatting with sample queries

**Days 3-4: Database Schema**
- [ ] Create PostgreSQL migrations
- [ ] Create routing_policies, candidate_models, executor_services, routing_decisions tables
- [ ] Load existing policies from policy editor requirements
- [ ] Test CRUD operations

**Day 5: DualRouter Skeleton**
- [ ] Create `internal/routing/dual_router.go`
- [ ] Implement Step 1: Arch-Router client
- [ ] Write unit tests for arch classification
- [ ] Get Arch-Router working in integration test

### Week 2: Core Logic

**Days 1-2: ExecutorRegistry & Candidate Merging**
- [ ] Create `internal/executors/registry.go`
- [ ] Integrate with ServiceDiscoveryManager
- [ ] Add Auggie/Cursor executor detection
- [ ] Implement candidate merging logic
- [ ] Test with sample executor list

**Days 3-4: MIRT-BERT Integration**
- [ ] Load MIRT checkpoint from 485: `/kush/smartcp/router/checkpoints/mirt_v1.pt`
- [ ] Wrap in Go: implement MIRTRouter client
- [ ] Load model abilities (25D vectors) into memory
- [ ] Implement scoring logic (IRT formula)
- [ ] Test with sample candidates

**Day 5: FeatureExtractor**
- [ ] Implement query feature extraction (complexity, code, etc.)
- [ ] Test on diverse prompts
- [ ] Tune difficulty computation

### Week 3: Integration & Testing

**Days 1-2: DualRouter Complete**
- [ ] Implement all Steps 2-6 in Route()
- [ ] Add MetricsTracker logging
- [ ] Implement fallback chain
- [ ] Test end-to-end flow

**Days 3-4: API Endpoints & Vibeproxy UI**
- [ ] Implement REST endpoints: `/api/routing/*`
- [ ] Add policy editor SwiftUI component
- [ ] Add executor status display
- [ ] Add routing decision visualization

**Day 5: Integration Tests**
- [ ] Test with real Arch-Router responses
- [ ] Test with MIRT scoring
- [ ] Test candidate merging
- [ ] Load testing: 100+ routing requests

### Week 4: Optimization & Monitoring

**Days 1-2: Performance Tuning**
- [ ] Cache MIRT model abilities
- [ ] Cache Arch-Router route configs
- [ ] Batch feature extraction
- [ ] Profile latency breakdown

**Days 3-4: Monitoring Dashboard**
- [ ] Add routing decision tracking
- [ ] Create accuracy metrics
- [ ] Add cost tracking visualization
- [ ] Export metrics to Prometheus

**Day 5: Documentation**
- [ ] Write operator manual
- [ ] Document policy configuration
- [ ] Create troubleshooting guide

### Week 5: Production Deployment

**Days 1-2: Staging Deployment**
- [ ] Deploy to staging environment
- [ ] Run 48-hour validation
- [ ] Monitor latency, accuracy, costs
- [ ] Prepare rollback plan

**Days 3-5: Production & Monitoring**
- [ ] Production deployment
- [ ] Gradual rollout (10% → 50% → 100%)
- [ ] 24/7 monitoring
- [ ] Begin collecting data for MIRT retraining

---

## 5. Files to Create/Modify

### New Files (Core Implementation)
- `internal/routing/dual_router.go` (500 LOC)
- `internal/routing/arch_router.go` (150 LOC)
- `internal/routing/mirt_client.go` (150 LOC)
- `internal/executors/registry.go` (300 LOC)
- `internal/routing/feature_extractor.go` (200 LOC)
- `api/routes/routing.go` (200 LOC)
- `migrations/xxx_create_routing_policies.sql`

### Modified Files (Integration)
- `main.go` - Initialize DualRouter, MLX client
- `Vibeproxy/SettingsView.swift` - Add RoutingPolicyEditor
- `config.yaml` - Add routing configuration
- `README.md` - Document routing system

---

## 6. Success Criteria

- [ ] Arch-Router classifies domain-action correctly (>90% accuracy on test set)
- [ ] MIRT-BERT scores candidates (latency <30ms)
- [ ] Candidates from 3+ executor sources merge correctly
- [ ] End-to-end latency <100ms (Arch 50ms + MIRT 30ms + overhead 20ms)
- [ ] Routing decisions logged (1000s of records per day)
- [ ] Policy editor works in Vibeproxy
- [ ] Executor health status displayed
- [ ] Cost reduction measured vs. baseline (target: 20-30%)
- [ ] Zero crashes/errors in 48-hour staging test

---

## 7. Risk Mitigation

| Risk | Mitigation |
|------|------------|
| MLX-LM server unavailable | Fallback to deterministic policy routing |
| MIRT model stale | Retraining pipeline automated weekly |
| Executor models disappear | Graceful degradation to fallback models |
| Arch-Router misclassifies | MIRT still ranks candidates by success |
| Policy DB down | Use in-memory cache with TTL |
| Latency regression | Caching + async feature extraction |

---

## 8. Next Steps

1. **Immediate (This week):**
   - [ ] Clone MIRT checkpoint path
   - [ ] Start MLX-LM server locally
   - [ ] Create database schema

2. **Following week:**
   - [ ] Implement DualRouter skeleton
   - [ ] Integrate ExecutorRegistry
   - [ ] Load MIRT model

3. **Then:**
   - [ ] Complete integration
   - [ ] Deploy to staging
   - [ ] Begin collection of routing metrics

---

**Owner:** Claude Code
**Created:** 2025-11-27
**Status:** Ready for Implementation
