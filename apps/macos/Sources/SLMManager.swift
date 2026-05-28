import Foundation
import Combine

// MARK: - Model Role Types
// Each local model serves a specific role in the routing/inference pipeline

enum ModelRole: String, Codable, CaseIterable, Identifiable {
    case modelRouter = "model_router"           // Routes requests to optimal cloud/local models
    case toolRouter = "tool_router"             // Routes tool calls to appropriate handlers
    case taskClassifier = "task_classifier"     // Classifies task complexity/type
    case summarizer = "summarizer"              // Context summarization for long conversations
    case codeAssistant = "code_assistant"       // Primary code generation/editing
    case reasoner = "reasoner"                  // Complex reasoning tasks
    case embedder = "embedder"                  // Text embeddings for semantic search
    case sentimentAnalyzer = "sentiment_analyzer" // Toxicity/emotion detection
    case contentModerator = "content_moderator" // Safety filtering
    case custom = "custom"                      // User-defined role

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modelRouter: return "Model Router"
        case .toolRouter: return "Tool Router"
        case .taskClassifier: return "Task Classifier"
        case .summarizer: return "Summarizer"
        case .codeAssistant: return "Code Assistant"
        case .reasoner: return "Reasoner"
        case .embedder: return "Embedder"
        case .sentimentAnalyzer: return "Sentiment Analyzer"
        case .contentModerator: return "Content Moderator"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .modelRouter: return "Routes requests to optimal models based on task complexity"
        case .toolRouter: return "Classifies and routes tool/function calls"
        case .taskClassifier: return "Analyzes task type and complexity dimensions"
        case .summarizer: return "Compresses context for long conversations"
        case .codeAssistant: return "Primary model for code generation and editing"
        case .reasoner: return "Handles complex multi-step reasoning"
        case .embedder: return "Generates embeddings for semantic operations"
        case .sentimentAnalyzer: return "Analyzes emotional context and toxicity (Detoxify/GoEmotions)"
        case .contentModerator: return "Pre/post-hook safety filtering for harmful content"
        case .custom: return "User-defined model role"
        }
    }

    var recommendedModels: [String] {
        switch self {
        case .modelRouter:
            return ["katanemo/Arch-Router-1.5B", "routellm/mf-router"]
        case .toolRouter:
            return ["katanemo/Arch-Router-1.5B", "mlx-community/Qwen2.5-Coder-1.5B-Instruct-4bit"]
        case .taskClassifier:
            return ["microsoft/deberta-v3-base", "katanemo/Arch-Router-1.5B"]
        case .summarizer:
            return ["mlx-community/Qwen2.5-7B-Instruct-4bit", "mlx-community/Llama-3.2-3B-Instruct-4bit"]
        case .codeAssistant:
            return ["mlx-community/Qwen2.5-Coder-32B-Instruct-4bit", "mlx-community/DeepSeek-R1-Distill-Qwen-32B-4bit"]
        case .reasoner:
            return ["mlx-community/DeepSeek-R1-Distill-Qwen-32B-4bit", "mlx-community/Qwen2.5-32B-Instruct-4bit"]
        case .embedder:
            return ["nomic-ai/nomic-embed-text-v1.5", "BAAI/bge-m3"]
        case .sentimentAnalyzer:
            return ["unitary/toxic-bert", "SamLowe/roberta-base-go_emotions", "cardiffnlp/twitter-roberta-base-sentiment-latest"]
        case .contentModerator:
            return ["unitary/unbiased-toxic-roberta", "martin-ha/toxic-comment-model"]
        case .custom:
            return []
        }
    }

    var defaultPort: Int {
        switch self {
        case .modelRouter: return 8008
        case .toolRouter: return 8009
        case .taskClassifier: return 8010
        case .summarizer: return 8011
        case .codeAssistant: return 8000
        case .reasoner: return 8001
        case .embedder: return 8012
        case .sentimentAnalyzer: return 8013
        case .contentModerator: return 8014
        case .custom: return 8080
        }
    }
}

// MARK: - Inference Backend Types

enum InferenceBackend: String, Codable, CaseIterable {
    case mlx = "mlx"
    case vllm = "vllm"
    case ollama = "ollama"
    case llamaCpp = "llama_cpp"
    case exllamav2 = "exllamav2"

    var displayName: String {
        switch self {
        case .mlx: return "MLX (Apple Silicon)"
        case .vllm: return "vLLM (CUDA)"
        case .ollama: return "Ollama"
        case .llamaCpp: return "llama.cpp"
        case .exllamav2: return "ExLlamaV2"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .mlx:
            #if arch(arm64) && os(macOS)
            return true
            #else
            return false
            #endif
        case .vllm, .exllamav2:
            #if os(macOS)
            return false
            #else
            return true
            #endif
        case .ollama, .llamaCpp:
            return true
        }
    }

    var supportsEmbeddings: Bool {
        switch self {
        case .mlx, .ollama, .llamaCpp: return true
        case .vllm, .exllamav2: return false
        }
    }
}

// MARK: - Model Instance Status

struct ModelInstanceStatus: Codable, Identifiable {
    let id: UUID
    let role: ModelRole
    let backend: String
    let running: Bool
    let model: String?
    let port: Int
    let uptime: TimeInterval?
    let requestsServed: Int
    let avgLatencyMs: Double?
    let error: String?

    var isHealthy: Bool {
        running && error == nil
    }
}

// MARK: - Model Instance Configuration

struct ModelInstanceConfig: Codable, Identifiable {
    let id: UUID
    var role: ModelRole
    var backend: InferenceBackend
    var model: String
    var port: Int
    var host: String
    var enabled: Bool
    var autoStart: Bool
    var maxContextLength: Int
    var quantization: String?
    var customArgs: [String]?

    static func defaultFor(role: ModelRole) -> ModelInstanceConfig {
        ModelInstanceConfig(
            id: UUID(),
            role: role,
            backend: .mlx,
            model: role.recommendedModels.first ?? "",
            port: role.defaultPort,
            host: "127.0.0.1",
            enabled: true,
            autoStart: role == .modelRouter || role == .codeAssistant,
            maxContextLength: 32768,
            quantization: "4bit",
            customArgs: nil
        )
    }
}

// MARK: - Discovered Model Info

struct DiscoveredModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let author: String?
    let downloads: Int?
    let size: String?
    let quantization: String?
    let backend: InferenceBackend
    let isInstalled: Bool
    let installPath: String?
    let recommendedRoles: [ModelRole]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiscoveredModel, rhs: DiscoveredModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Local Model Manager
// Manages multiple model instances with role-based configuration

class LocalModelManager: ObservableObject {
    static let shared = LocalModelManager()

    @Published var instances: [UUID: ModelInstanceConfig] = [:]
    @Published var statuses: [UUID: ModelInstanceStatus] = [:]
    @Published var discoveredModels: [DiscoveredModel] = []
    @Published var isDiscovering = false
    @Published var logs: [String] = []

    private var processes: [UUID: Process] = [:]
    private var healthCheckTimer: Timer?
    private let configPath: URL
    private let processQueue = DispatchQueue(label: "io.automaze.vibeproxy.models", qos: .userInitiated)

    // Common MLX model cache paths
    private let mlxCachePaths: [String] = [
        "~/.cache/huggingface/hub",
        "~/Library/Caches/huggingface/hub",
        "~/.cache/mlx-lm"
    ]

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("VibeProxy", isDirectory: true)
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        configPath = configDir.appendingPathComponent("model-instances.json")

        loadConfig()
        discoverInstalledModels()
        startHealthCheck()
    }

    deinit {
        stopAll()
    }

    // MARK: - Configuration

    private func loadConfig() {
        if let data = try? Data(contentsOf: configPath),
           let loaded = try? JSONDecoder().decode([UUID: ModelInstanceConfig].self, from: data) {
            instances = loaded
        } else {
            // Create default instances for essential roles
            let routerConfig = ModelInstanceConfig.defaultFor(role: .modelRouter)
            let codeConfig = ModelInstanceConfig.defaultFor(role: .codeAssistant)
            instances = [routerConfig.id: routerConfig, codeConfig.id: codeConfig]
            saveConfig()
        }
    }

    func saveConfig() {
        if let data = try? JSONEncoder().encode(instances) {
            try? data.write(to: configPath)
        }
    }

    // MARK: - Instance Management

    func addInstance(_ config: ModelInstanceConfig) {
        instances[config.id] = config
        saveConfig()
    }

    func removeInstance(_ id: UUID) {
        stop(id)
        instances.removeValue(forKey: id)
        statuses.removeValue(forKey: id)
        saveConfig()
    }

    func updateInstance(_ config: ModelInstanceConfig) {
        let wasRunning = statuses[config.id]?.running ?? false
        if wasRunning { stop(config.id) }
        instances[config.id] = config
        saveConfig()
        if wasRunning && config.enabled { start(config.id) { _ in } }
    }

    func getInstance(for role: ModelRole) -> ModelInstanceConfig? {
        instances.values.first { $0.role == role && $0.enabled }
    }

    // MARK: - Lifecycle

    func start(_ id: UUID, completion: @escaping (Bool) -> Void) {
        guard let config = instances[id], config.enabled else {
            completion(false)
            return
        }

        addLog("Starting \(config.role.displayName): \(config.model)")

        processQueue.async { [weak self] in
            guard let self = self else { return }
            let success = self.launchInstance(config)
            DispatchQueue.main.async {
                if success {
                    self.addLog("✓ \(config.role.displayName) started on port \(config.port)")
                } else {
                    self.addLog("✗ Failed to start \(config.role.displayName)")
                }
                completion(success)
            }
        }
    }

    func stop(_ id: UUID) {
        if let proc = processes[id], proc.isRunning {
            proc.terminate()
            processes.removeValue(forKey: id)
        }
        if let config = instances[id] {
            statuses[id] = ModelInstanceStatus(
                id: id, role: config.role, backend: config.backend.rawValue,
                running: false, model: config.model, port: config.port,
                uptime: nil, requestsServed: 0, avgLatencyMs: nil, error: nil
            )
        }
    }

    func stopAll() {
        healthCheckTimer?.invalidate()
        for id in processes.keys { stop(id) }
    }

    func startAll(completion: @escaping (Int, Int) -> Void) {
        let enabledInstances = instances.filter { $0.value.enabled && $0.value.autoStart }
        var started = 0
        var failed = 0
        let group = DispatchGroup()

        for (id, _) in enabledInstances {
            group.enter()
            start(id) { success in
                if success { started += 1 } else { failed += 1 }
                group.leave()
            }
        }

        group.notify(queue: .main) { completion(started, failed) }
    }

    // MARK: - Backend Launch

    private func launchInstance(_ config: ModelInstanceConfig) -> Bool {
        switch config.backend {
        case .mlx: return launchMLX(config)
        case .ollama: return launchOllama(config)
        case .llamaCpp: return launchLlamaCpp(config)
        default:
            addLog("\(config.backend.displayName) not available on this platform")
            return false
        }
    }

    private func launchMLX(_ config: ModelInstanceConfig) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["python3", "-m", "mlx_lm.server",
                    "--model", config.model,
                    "--host", config.host,
                    "--port", String(config.port)]
        if let customArgs = config.customArgs { args.append(contentsOf: customArgs) }
        proc.arguments = args

        setupProcessOutput(proc, for: config)

        do {
            try proc.run()
            processes[config.id] = proc
            return true
        } catch {
            addLog("Error launching MLX for \(config.role.displayName): \(error.localizedDescription)")
            return false
        }
    }

    private func launchOllama(_ config: ModelInstanceConfig) -> Bool {
        // Ollama uses a single server, so we just ensure it's running
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        proc.arguments = ["serve"]

        do {
            try proc.run()
            processes[config.id] = proc
            return true
        } catch {
            addLog("Error launching Ollama: \(error.localizedDescription)")
            return false
        }
    }

    private func launchLlamaCpp(_ config: ModelInstanceConfig) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/local/bin/llama-server")
        var args = ["-m", config.model, "--host", config.host, "--port", String(config.port)]
        if let customArgs = config.customArgs { args.append(contentsOf: customArgs) }
        proc.arguments = args

        setupProcessOutput(proc, for: config)

        do {
            try proc.run()
            processes[config.id] = proc
            return true
        } catch {
            addLog("Error launching llama.cpp: \(error.localizedDescription)")
            return false
        }
    }

    private func setupProcessOutput(_ proc: Process, for config: ModelInstanceConfig) {
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    self?.addLog("[\(config.role.displayName)] \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        }
    }

    // MARK: - Model Discovery

    func discoverInstalledModels() {
        isDiscovering = true
        processQueue.async { [weak self] in
            var discovered: [DiscoveredModel] = []

            // Discover MLX models from HuggingFace cache
            discovered.append(contentsOf: self?.discoverMLXModels() ?? [])

            // Discover Ollama models
            discovered.append(contentsOf: self?.discoverOllamaModels() ?? [])

            DispatchQueue.main.async {
                self?.discoveredModels = discovered
                self?.isDiscovering = false
                self?.addLog("Discovered \(discovered.count) installed models")
            }
        }
    }

    private func discoverMLXModels() -> [DiscoveredModel] {
        var models: [DiscoveredModel] = []
        let fm = FileManager.default

        for cachePath in mlxCachePaths {
            let expandedPath = NSString(string: cachePath).expandingTildeInPath
            guard let contents = try? fm.contentsOfDirectory(atPath: expandedPath) else { continue }

            for item in contents {
                // HuggingFace cache uses "models--org--name" format
                if item.hasPrefix("models--") {
                    let parts = item.replacingOccurrences(of: "models--", with: "").components(separatedBy: "--")
                    if parts.count >= 2 {
                        let modelId = "\(parts[0])/\(parts[1...].joined(separator: "-"))"
                        let fullPath = "\(expandedPath)/\(item)"

                        // Determine recommended roles based on model name
                        let roles = inferRolesFromModelName(modelId)

                        let model = DiscoveredModel(
                            id: modelId,
                            name: parts[1...].joined(separator: "-"),
                            author: parts[0],
                            downloads: nil,
                            size: getDirectorySize(fullPath),
                            quantization: inferQuantization(modelId),
                            backend: .mlx,
                            isInstalled: true,
                            installPath: fullPath,
                            recommendedRoles: roles
                        )
                        models.append(model)
                    }
                }
            }
        }

        return models
    }

    private func discoverOllamaModels() -> [DiscoveredModel] {
        var models: [DiscoveredModel] = []

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        proc.arguments = ["list"]

        let pipe = Pipe()
        proc.standardOutput = pipe

        do {
            try proc.run()
            proc.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n").dropFirst() // Skip header
                for line in lines where !line.isEmpty {
                    let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if let name = parts.first {
                        let roles = inferRolesFromModelName(name)
                        models.append(DiscoveredModel(
                            id: "ollama/\(name)",
                            name: name,
                            author: "ollama",
                            downloads: nil,
                            size: parts.count > 1 ? parts[1] : nil,
                            quantization: nil,
                            backend: .ollama,
                            isInstalled: true,
                            installPath: nil,
                            recommendedRoles: roles
                        ))
                    }
                }
            }
        } catch {
            addLog("Error discovering Ollama models: \(error.localizedDescription)")
        }

        return models
    }

    private func inferRolesFromModelName(_ name: String) -> [ModelRole] {
        let lowercased = name.lowercased()
        var roles: [ModelRole] = []

        if lowercased.contains("arch-router") || lowercased.contains("router") {
            roles.append(.modelRouter)
            roles.append(.toolRouter)
        }
        if lowercased.contains("coder") || lowercased.contains("code") {
            roles.append(.codeAssistant)
        }
        if lowercased.contains("deepseek-r1") || lowercased.contains("reason") {
            roles.append(.reasoner)
        }
        if lowercased.contains("embed") || lowercased.contains("bge") || lowercased.contains("nomic") {
            roles.append(.embedder)
        }
        if lowercased.contains("qwen") && !lowercased.contains("coder") {
            roles.append(.summarizer)
            roles.append(.taskClassifier)
        }

        if roles.isEmpty { roles.append(.custom) }
        return roles
    }

    private func inferQuantization(_ name: String) -> String? {
        let lowercased = name.lowercased()
        if lowercased.contains("4bit") || lowercased.contains("q4") { return "4bit" }
        if lowercased.contains("8bit") || lowercased.contains("q8") { return "8bit" }
        if lowercased.contains("fp16") { return "fp16" }
        return nil
    }

    private func getDirectorySize(_ path: String) -> String? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else { return nil }

        var totalSize: Int64 = 0
        while let file = enumerator.nextObject() as? String {
            let fullPath = "\(path)/\(file)"
            if let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    // MARK: - Health Check

    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkAllHealth()
        }
    }

    private func checkAllHealth() {
        for (id, config) in instances where config.enabled {
            checkHealth(id: id, config: config)
        }
    }

    private func checkHealth(id: UUID, config: ModelInstanceConfig) {
        let url = URL(string: "http://\(config.host):\(config.port)/health")!
        URLSession.shared.dataTask(with: url) { [weak self] _, response, error in
            DispatchQueue.main.async {
                let isRunning = (response as? HTTPURLResponse)?.statusCode == 200
                self?.statuses[id] = ModelInstanceStatus(
                    id: id, role: config.role, backend: config.backend.rawValue,
                    running: isRunning, model: config.model, port: config.port,
                    uptime: nil, requestsServed: 0, avgLatencyMs: nil,
                    error: error?.localizedDescription
                )
            }
        }.resume()
    }

    // MARK: - Logging

    private func addLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        DispatchQueue.main.async {
            self.logs.append("[\(timestamp)] \(message)")
            if self.logs.count > 500 { self.logs.removeFirst(100) }
        }
    }

    func clearLogs() { logs.removeAll() }

    // MARK: - HuggingFace Search

    func searchModels(query: String, backend: InferenceBackend, completion: @escaping ([DiscoveredModel]) -> Void) {
        guard query.count >= 3 else { completion([]); return }

        let prefix = backend == .mlx ? "mlx-community" : ""
        let searchQuery = prefix.isEmpty ? query : "\(prefix)/\(query)"

        let urlString = "https://huggingface.co/api/models?search=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=20"
        guard let url = URL(string: urlString) else { completion([]); return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            do {
                let models = try JSONDecoder().decode([HuggingFaceModel].self, from: data)
                let discovered = models.map { hf -> DiscoveredModel in
                    let roles = self?.inferRolesFromModelName(hf.id) ?? [.custom]
                    return DiscoveredModel(
                        id: hf.id,
                        name: hf.id.components(separatedBy: "/").last ?? hf.id,
                        author: hf.author,
                        downloads: hf.downloads,
                        size: nil,
                        quantization: self?.inferQuantization(hf.id),
                        backend: backend,
                        isInstalled: false,
                        installPath: nil,
                        recommendedRoles: roles
                    )
                }
                DispatchQueue.main.async { completion(discovered) }
            } catch {
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
}

// MARK: - HuggingFace API Model

private struct HuggingFaceModel: Codable {
    let id: String
    let author: String?
    let downloads: Int?
}

// MARK: - Legacy Compatibility Alias
typealias SLMManager = LocalModelManager

