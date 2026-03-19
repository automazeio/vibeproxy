# Model Groups Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users define virtual model names that round-robin across multiple real models from different providers, with same-request failover.

**Architecture:** New `ModelGroupRouter` in ThinkingProxy intercepts requests for group model names, rewrites the `model` field to the next real model in rotation, and retries on failure with the next model. Groups are configured in Settings UI and persisted via UserDefaults. The `/v1/models` response is intercepted to inject group entries.

**Tech Stack:** Swift, SwiftUI, Network framework (NWConnection), JSONSerialization

---

### Task 1: Create ModelGroup Data Model

**Files:**
- Create: `src/Sources/ModelGroup.swift`

**Step 1: Create the ModelGroup struct and ModelGroupRouter class**

```swift
import Foundation

struct ModelGroup: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var models: [String]
    var enabled: Bool

    init(id: UUID = UUID(), name: String = "", models: [String] = [], enabled: Bool = true) {
        self.id = id
        self.name = name
        self.models = models
        self.enabled = enabled
    }
}

class ModelGroupRouter {
    private var groups: [ModelGroup] = []
    private var counters: [UUID: Int] = [:]
    private let lock = NSLock()

    func updateGroups(_ newGroups: [ModelGroup]) {
        lock.lock()
        defer { lock.unlock() }
        groups = newGroups.filter { $0.enabled && !$0.models.isEmpty }
        // Prune counters for removed groups
        let validIds = Set(groups.map(\.id))
        counters = counters.filter { validIds.contains($0.key) }
    }

    /// Returns nil if model is not a group name
    func resolveModel(_ model: String) -> (groupId: UUID, realModel: String)? {
        lock.lock()
        defer { lock.unlock() }
        guard let group = groups.first(where: { $0.name == model }) else { return nil }
        let index = counters[group.id, default: 0] % group.models.count
        counters[group.id] = index + 1
        return (group.id, group.models[index])
    }

    /// Get next model in group, excluding already-tried models. Returns nil when exhausted.
    func failoverModel(groupId: UUID, excluding tried: Set<String>) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let group = groups.first(where: { $0.id == groupId }) else { return nil }
        return group.models.first { !tried.contains($0) }
    }

    /// All enabled group names (for /v1/models injection)
    func activeGroupNames() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return groups.map(\.name)
    }
}
```

**Step 2: Verify it compiles**

Run: `cd /Users/yusufisawi/Developer/expirements/vibeproxy/src && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add src/Sources/ModelGroup.swift
git commit -m "feat: add ModelGroup data model and router"
```

---

### Task 2: Add ModelGroup Persistence to ServerManager

**Files:**
- Modify: `src/Sources/ServerManager.swift`

**Step 1: Add modelGroups property with UserDefaults persistence**

After the `vercelApiKey` property (around line 71), add:

```swift
@Published var modelGroups: [ModelGroup] = [] {
    didSet {
        if let data = try? JSONEncoder().encode(modelGroups) {
            UserDefaults.standard.set(data, forKey: "modelGroups")
        }
        onModelGroupsChanged?()
    }
}

var onModelGroupsChanged: (() -> Void)?
```

**Step 2: Load saved groups in init()**

In the `init()` method (around line 107), add after `vercelApiKey` loading:

```swift
if let data = UserDefaults.standard.data(forKey: "modelGroups"),
   let saved = try? JSONDecoder().decode([ModelGroup].self, from: data) {
    modelGroups = saved
}
```

**Step 3: Verify it compiles**

Run: `cd /Users/yusufisawi/Developer/expirements/vibeproxy/src && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add src/Sources/ServerManager.swift
git commit -m "feat: persist model groups in ServerManager via UserDefaults"
```

---

### Task 3: Wire ModelGroupRouter into ThinkingProxy

**Files:**
- Modify: `src/Sources/ThinkingProxy.swift`

**Step 1: Add router property to ThinkingProxy**

After `var vercelConfig` (line 43), add:

```swift
let modelGroupRouter = ModelGroupRouter()
```

**Step 2: Sync groups from AppDelegate**

In `src/Sources/AppDelegate.swift`, after the `syncVercelConfig()` call (line 39) and its callback (lines 40-42), add:

```swift
syncModelGroups()
serverManager.onModelGroupsChanged = { [weak self] in
    self?.syncModelGroups()
}
```

Add the sync method near `syncVercelConfig()` (after line 401):

```swift
private func syncModelGroups() {
    thinkingProxy.modelGroupRouter.updateGroups(serverManager.modelGroups)
}
```

**Step 3: Verify it compiles**

Run: `cd /Users/yusufisawi/Developer/expirements/vibeproxy/src && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add src/Sources/ThinkingProxy.swift src/Sources/AppDelegate.swift
git commit -m "feat: wire ModelGroupRouter into ThinkingProxy via AppDelegate"
```

---

### Task 4: Intercept Requests for Model Groups in processRequest

**Files:**
- Modify: `src/Sources/ThinkingProxy.swift`

This is the core routing logic. In `processRequest`, after the thinking parameter processing (line 294) and before the usage recording (line 296), we resolve model groups.

**Step 1: Add model group resolution in processRequest**

After line 294 (`}`) and before line 296 (`if isCliProxyUsagePath`), insert:

```swift
// Resolve model group — rewrite model name to real model via round-robin
var modelGroupContext: (groupId: UUID, triedModels: Set<String>)? = nil
if method == "POST" && !modifiedBody.isEmpty {
    if let resolved = resolveModelGroup(body: modifiedBody) {
        modifiedBody = resolved.rewrittenBody
        modelGroupContext = (resolved.groupId, [resolved.realModel])
        NSLog("[ThinkingProxy] Model group resolved: '\(resolved.groupName)' → '\(resolved.realModel)'")
    }
}
```

**Step 2: Add the resolveModelGroup helper method**

Add this method to ThinkingProxy (near `extractModel` around line 380):

```swift
private struct ModelGroupResolution {
    let groupName: String
    let groupId: UUID
    let realModel: String
    let rewrittenBody: String
}

private func resolveModelGroup(body: String) -> ModelGroupResolution? {
    guard let data = body.data(using: .utf8),
          var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let model = json["model"] as? String else {
        return nil
    }

    guard let resolved = modelGroupRouter.resolveModel(model) else { return nil }

    json["model"] = resolved.realModel
    guard let modifiedData = try? JSONSerialization.data(withJSONObject: json),
          let modifiedString = String(data: modifiedData, encoding: .utf8) else {
        return nil
    }

    return ModelGroupResolution(
        groupName: model,
        groupId: resolved.groupId,
        realModel: resolved.realModel,
        rewrittenBody: modifiedString
    )
}
```

**Step 3: Add a rewriteModelInBody helper for failover retries**

```swift
private func rewriteModelInBody(_ body: String, to newModel: String) -> String? {
    guard let data = body.data(using: .utf8),
          var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    json["model"] = newModel
    guard let modified = try? JSONSerialization.data(withJSONObject: json),
          let result = String(data: modified, encoding: .utf8) else {
        return nil
    }
    return result
}
```

**Step 4: Update the forwardRequest call at line 307 to pass group context**

Change line 307 from:
```swift
forwardRequest(method: method, path: rewrittenPath, version: httpVersion, headers: headers, body: modifiedBody, thinkingEnabled: thinkingEnabled, originalConnection: connection)
```
To:
```swift
forwardRequest(method: method, path: rewrittenPath, version: httpVersion, headers: headers, body: modifiedBody, thinkingEnabled: thinkingEnabled, originalConnection: connection, modelGroupContext: modelGroupContext)
```

**Step 5: Update forwardRequest signature to accept modelGroupContext**

Change line 902 signature to add the optional parameter:

```swift
private func forwardRequest(method: String, path: String, version: String, headers: [(String, String)], body: String, thinkingEnabled: Bool = false, originalConnection: NWConnection, retryWithApiPrefix: Bool = false, modelGroupContext: (groupId: UUID, triedModels: Set<String>)? = nil) {
```

And update the `receiveResponse` call at line ~999 (inside the `.ready` state handler). If `modelGroupContext` is set, use the new retry-aware receiver instead:

```swift
if let groupCtx = modelGroupContext {
    self.receiveResponseWithGroupFailover(
        from: targetConnection,
        originalConnection: originalConnection,
        method: method, path: path, version: version,
        headers: headers, body: body,
        thinkingEnabled: thinkingEnabled,
        groupContext: groupCtx
    )
} else if retryWithApiPrefix {
    self.receiveResponseWith404Retry(from: targetConnection, originalConnection: originalConnection,
                                     method: method, path: path, version: version,
                                     headers: headers, body: body)
} else {
    self.receiveResponse(from: targetConnection, originalConnection: originalConnection)
}
```

**Step 6: Verify it compiles (will fail until Task 5 adds receiveResponseWithGroupFailover)**

This is expected — we add the failover method in Task 5.

**Step 7: Commit (WIP)**

```bash
git add src/Sources/ThinkingProxy.swift
git commit -m "feat(wip): model group resolution in processRequest"
```

---

### Task 5: Implement Response Failover for Model Groups

**Files:**
- Modify: `src/Sources/ThinkingProxy.swift`

The key challenge: we need to buffer the initial response to check the HTTP status code. If it's an error (429/500/502/503), retry with the next model. If 200, stream normally.

**Step 1: Add receiveResponseWithGroupFailover method**

```swift
private func receiveResponseWithGroupFailover(
    from targetConnection: NWConnection,
    originalConnection: NWConnection,
    method: String, path: String, version: String,
    headers: [(String, String)], body: String,
    thinkingEnabled: Bool,
    groupContext: (groupId: UUID, triedModels: Set<String>)
) {
    targetConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
        guard let self = self else { return }

        if let error = error {
            NSLog("[ThinkingProxy] Group failover receive error: \(error)")
            // Network error — try next model
            targetConnection.cancel()
            self.retryWithNextGroupModel(
                originalConnection: originalConnection,
                method: method, path: path, version: version,
                headers: headers, body: body,
                thinkingEnabled: thinkingEnabled,
                groupContext: groupContext
            )
            return
        }

        guard let data = data, !data.isEmpty else {
            targetConnection.cancel()
            originalConnection.cancel()
            return
        }

        // Check HTTP status from first chunk
        let statusCode = self.extractHttpStatus(from: data)
        let isRetryable = [429, 500, 502, 503].contains(statusCode)

        if isRetryable {
            NSLog("[ThinkingProxy] Model group got \(statusCode ?? 0), attempting failover")
            targetConnection.cancel()
            self.retryWithNextGroupModel(
                originalConnection: originalConnection,
                method: method, path: path, version: version,
                headers: headers, body: body,
                thinkingEnabled: thinkingEnabled,
                groupContext: groupContext
            )
        } else {
            // Success or non-retryable error — forward first chunk then stream rest
            originalConnection.send(content: data, completion: .contentProcessed({ sendError in
                if let sendError = sendError {
                    NSLog("[ThinkingProxy] Send response error: \(sendError)")
                }
                if isComplete {
                    targetConnection.cancel()
                    originalConnection.send(content: nil, isComplete: true, completion: .contentProcessed({ _ in
                        originalConnection.cancel()
                    }))
                } else {
                    self.streamNextChunk(from: targetConnection, to: originalConnection)
                }
            }))
        }
    }
}

private func retryWithNextGroupModel(
    originalConnection: NWConnection,
    method: String, path: String, version: String,
    headers: [(String, String)], body: String,
    thinkingEnabled: Bool,
    groupContext: (groupId: UUID, triedModels: Set<String>)
) {
    guard let nextModel = modelGroupRouter.failoverModel(groupId: groupContext.groupId, excluding: groupContext.triedModels),
          let rewrittenBody = rewriteModelInBody(body, to: nextModel) else {
        NSLog("[ThinkingProxy] Model group exhausted all models, returning 503")
        sendError(to: originalConnection, statusCode: 503, message: "All models in group exhausted")
        return
    }

    NSLog("[ThinkingProxy] Model group failover → '\(nextModel)'")
    var updatedContext = groupContext
    updatedContext.triedModels.insert(nextModel)

    forwardRequest(
        method: method, path: path, version: version,
        headers: headers, body: rewrittenBody,
        thinkingEnabled: thinkingEnabled,
        originalConnection: originalConnection,
        modelGroupContext: updatedContext
    )
}

private func extractHttpStatus(from data: Data) -> Int? {
    // Parse "HTTP/1.1 NNN" from first line of response
    guard let str = String(data: data.prefix(32), encoding: .utf8) else { return nil }
    let parts = str.components(separatedBy: " ")
    guard parts.count >= 2, let code = Int(parts[1]) else { return nil }
    return code
}
```

**Step 2: Verify it compiles**

Run: `cd /Users/yusufisawi/Developer/expirements/vibeproxy/src && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add src/Sources/ThinkingProxy.swift
git commit -m "feat: model group failover with status-based retry"
```

---

### Task 6: Inject Model Groups into /v1/models Response

**Files:**
- Modify: `src/Sources/ThinkingProxy.swift`

For GET `/v1/models`, we need to buffer the full response from CLIProxyAPIPlus, parse JSON, inject group entries, and return.

**Step 1: Add interception in processRequest**

In `processRequest`, before the final `forwardRequest` call (line 307), add a check for the models endpoint:

```swift
// Intercept /v1/models to inject model groups
if method == "GET" && (rewrittenPath == "/v1/models" || rewrittenPath == "/api/v1/models") {
    let groupNames = modelGroupRouter.activeGroupNames()
    if !groupNames.isEmpty {
        forwardRequestAndInjectModels(method: method, path: rewrittenPath, version: httpVersion, headers: headers, body: modifiedBody, groupNames: groupNames, originalConnection: connection)
        return
    }
}
```

**Step 2: Add forwardRequestAndInjectModels method**

```swift
private func forwardRequestAndInjectModels(method: String, path: String, version: String, headers: [(String, String)], body: String, groupNames: [String], originalConnection: NWConnection) {
    guard let port = NWEndpoint.Port(rawValue: targetPort) else {
        sendError(to: originalConnection, statusCode: 500, message: "Internal Server Error")
        return
    }
    let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(targetHost), port: port)
    let targetConnection = NWConnection(to: endpoint, using: NWParameters.tcp)

    targetConnection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            var req = "\(method) \(path) \(version)\r\n"
            let excluded: Set<String> = ["content-length", "host", "transfer-encoding"]
            for (name, value) in headers where !excluded.contains(name.lowercased()) {
                req += "\(name): \(value)\r\n"
            }
            req += "Host: \(self.targetHost):\(self.targetPort)\r\n"
            req += "Connection: close\r\n"
            let contentLength = body.utf8.count
            req += "Content-Length: \(contentLength)\r\n\r\n\(body)"

            if let data = req.data(using: .utf8) {
                targetConnection.send(content: data, completion: .contentProcessed({ error in
                    if let error = error {
                        NSLog("[ThinkingProxy] Models inject send error: \(error)")
                        targetConnection.cancel()
                        originalConnection.cancel()
                    } else {
                        self.bufferFullResponse(from: targetConnection) { responseData in
                            guard let responseData = responseData else {
                                self.sendError(to: originalConnection, statusCode: 502, message: "Bad Gateway")
                                return
                            }
                            let injected = self.injectGroupModels(into: responseData, groupNames: groupNames)
                            originalConnection.send(content: injected, completion: .contentProcessed({ _ in
                                originalConnection.send(content: nil, isComplete: true, completion: .contentProcessed({ _ in
                                    originalConnection.cancel()
                                }))
                            }))
                        }
                    }
                }))
            }
        case .failed(let error):
            NSLog("[ThinkingProxy] Models inject connection failed: \(error)")
            self.sendError(to: originalConnection, statusCode: 502, message: "Bad Gateway")
            targetConnection.cancel()
        default: break
        }
    }
    targetConnection.start(queue: .global(qos: .userInitiated))
}

private func bufferFullResponse(from connection: NWConnection, accumulated: Data = Data(), completion: @escaping (Data?) -> Void) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
        if let error = error {
            NSLog("[ThinkingProxy] Buffer response error: \(error)")
            connection.cancel()
            completion(nil)
            return
        }
        var buffer = accumulated
        if let data = data { buffer.append(data) }
        if isComplete {
            connection.cancel()
            completion(buffer)
        } else {
            self.bufferFullResponse(from: connection, accumulated: buffer, completion: completion)
        }
    }
}

private func injectGroupModels(into responseData: Data, groupNames: [String]) -> Data {
    // Split HTTP response into headers and body
    guard let responseStr = String(data: responseData, encoding: .utf8),
          let headerEnd = responseStr.range(of: "\r\n\r\n") else {
        return responseData
    }

    let bodyStr = String(responseStr[headerEnd.upperBound...])
    guard let bodyData = bodyStr.data(using: .utf8),
          var json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
          var dataArray = json["data"] as? [[String: Any]] else {
        return responseData
    }

    // Inject group models
    for name in groupNames {
        dataArray.append([
            "id": name,
            "object": "model",
            "created": Int(Date().timeIntervalSince1970),
            "owned_by": "vibeproxy"
        ])
    }
    json["data"] = dataArray

    guard let newBody = try? JSONSerialization.data(withJSONObject: json),
          let newBodyStr = String(data: newBody, encoding: .utf8) else {
        return responseData
    }

    // Rebuild HTTP response with updated Content-Length
    let newResponse = "HTTP/1.1 200 OK\r\n" +
        "Content-Type: application/json\r\n" +
        "Content-Length: \(newBody.count)\r\n" +
        "Connection: close\r\n" +
        "\r\n" +
        newBodyStr

    return newResponse.data(using: .utf8) ?? responseData
}
```

**Step 3: Verify it compiles**

Run: `cd /Users/yusufisawi/Developer/expirements/vibeproxy/src && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add src/Sources/ThinkingProxy.swift
git commit -m "feat: inject model groups into /v1/models response"
```

---

### Task 7: Build Settings UI for Model Groups

**Files:**
- Modify: `src/Sources/SettingsView.swift`

**Step 1: Add new "Model Groups" section**

In the Form body, between the `Section("Services")` closing brace (line 515) and `Section("Available Models")` (line 517), add:

```swift
Section("Model Groups") {
    if serverManager.modelGroups.isEmpty {
        Text("No model groups configured")
            .font(.caption)
            .foregroundColor(.secondary)
    } else {
        ForEach($serverManager.modelGroups) { $group in
            ModelGroupRow(group: $group, onDelete: {
                serverManager.modelGroups.removeAll { $0.id == group.id }
            })
        }
    }

    Button(action: {
        serverManager.modelGroups.append(ModelGroup())
    }) {
        HStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
                .font(.caption)
            Text("Add Model Group")
                .font(.caption)
        }
    }
    .buttonStyle(.plain)
    .foregroundColor(.accentColor)
}
```

**Step 2: Create ModelGroupRow view**

Add this above the SettingsView struct (near the other helper views like AccountRowView):

```swift
struct ModelGroupRow: View {
    @Binding var group: ModelGroup
    let onDelete: () -> Void
    @State private var newModelName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Toggle("", isOn: $group.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                TextField("Group name", text: $group.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: 160)

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }

            // Linked models
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(group.models.enumerated()), id: \.offset) { index, model in
                    HStack(spacing: 6) {
                        Text("\(index + 1).")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 16, alignment: .trailing)
                        Text(model)
                            .font(.system(size: 11, design: .monospaced))
                        Spacer()
                        Button(action: {
                            group.models.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                }

                HStack(spacing: 6) {
                    TextField("Model name (e.g. gpt-5)", text: $newModelName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .onSubmit { addModel() }

                    Button(action: addModel) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .disabled(newModelName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.leading, 32)
        }
        .padding(.vertical, 4)
    }

    private func addModel() {
        let trimmed = newModelName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        group.models.append(trimmed)
        newModelName = ""
    }
}
```

**Step 3: Update window height to accommodate new section**

Change the frame height (line 644) from 780 to 860:

```swift
.frame(width: 480, height: 860)
```

**Step 4: Verify it compiles**

Run: `cd /Users/yusufisawi/Developer/expirements/vibeproxy/src && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add src/Sources/SettingsView.swift
git commit -m "feat: model groups settings UI"
```

---

### Task 8: Update providerForModel for Model Groups

**Files:**
- Modify: `src/Sources/ThinkingProxy.swift`

The `providerForModel` function is used for usage tracking. When a request uses a model group, usage should be tracked under the real model's provider, not "other". Since we rewrite the model before `recordUsage` is called, this should already work. However, we should also handle the case where the original group name shows up.

**Step 1: Update providerForModel to check groups**

At the top of `providerForModel`, add:

```swift
if modelGroupRouter.resolveModel(lower) != nil {
    return "vibeproxy-group"
}
```

Actually — since the model is already rewritten to the real model before `recordUsage` is called (resolution happens at line ~296, usage at ~298), the provider will be correctly detected from the real model name. No change needed here.

**Step 1: Verify end-to-end flow manually**

Run: `cd /Users/yusufisawi/Developer/expirements/vibeproxy/src && swift build 2>&1 | tail -5`
Expected: Build succeeds

**Step 2: Test manually**

1. Launch the app
2. Go to Settings → Model Groups
3. Create a group named "high" with models: `gpt-5`, `claude-sonnet-4-5-20250929`
4. Enable it
5. Check `/v1/models` — verify "high" appears with owned_by "vibeproxy"
6. Send a request with `"model": "high"` — verify it reaches one of the real models
7. Send multiple requests — verify round-robin alternation in logs
8. Disable one provider to force failure — verify failover to next model

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete model groups with round-robin and failover"
```

---

## Testing Checklist

- [ ] Model group appears in /v1/models alongside real models
- [ ] Request with group name rewrites to real model (check NSLog output)
- [ ] Round-robin alternates between models across requests
- [ ] On 429/500/502/503, automatically retries with next model in group
- [ ] When all models in group fail, returns 503
- [ ] Disabling a group removes it from /v1/models
- [ ] Groups persist across app restarts (UserDefaults)
- [ ] Empty group name or models list is handled gracefully
- [ ] Thinking suffix still works on real models resolved from groups
- [ ] Usage tracking shows the real model name, not the group name
