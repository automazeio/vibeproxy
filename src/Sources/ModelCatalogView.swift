import SwiftUI
import AppKit

// Represents a model exposed by the local CLIProxyAPIPlus proxy.
struct ModelEntry: Identifiable, Hashable {
    let id: String
    let providerName: String    // Human label (e.g., "Anthropic")
    let providerKey: String     // Route key (e.g., "anthropic", "openai", "google", "groq")
    let label: String
    let ownedBy: String?

    var displayLabel: String {
        label.isEmpty ? id : label
    }

    var displayProvider: String {
        providerName.isEmpty ? "Unknown" : providerName
    }
}

// Grouping buckets mirroring Services.
enum ServiceBucket: String, CaseIterable {
    case antigravity = "Antigravity"
    case claude = "Claude Code"
    case codex = "Codex"
    case gemini = "Gemini"
    case copilot = "GitHub Copilot"
    case qwen = "Qwen"
    case groq = "Groq"
    case other = "Other"

    static var ordered: [ServiceBucket] {
        [.antigravity, .claude, .codex, .gemini, .copilot, .qwen, .groq, .other]
    }

    var routeProviderKey: String {
        switch self {
        case .claude: return "anthropic"
        case .gemini: return "google"
        case .groq: return "groq"
        case .copilot: return "openai"
        case .codex, .antigravity, .qwen, .other: return "openai"
        }
    }

    static func classify(providerKey: String, providerName: String, ownedBy: String?, modelID: String) -> ServiceBucket {
        let lowerKey = providerKey.lowercased()
        let lowerName = providerName.lowercased()
        let lowerOwned = ownedBy?.lowercased() ?? ""
        let lowerID = modelID.lowercased()

        if lowerKey.contains("antigravity") || lowerName.contains("antigravity") || lowerOwned.contains("antigravity") {
            return .antigravity
        }
        if lowerKey.contains("anthropic") || lowerName.contains("anthropic") || lowerName.contains("claude") || lowerOwned.contains("anthropic") || lowerOwned.contains("claude") {
            return .claude
        }
        if lowerKey.contains("google") || lowerName.contains("google") || lowerName.contains("gemini") || lowerOwned.contains("google") || lowerOwned.contains("gemini") {
            return .gemini
        }
        if lowerKey.contains("groq") || lowerName.contains("groq") {
            return .groq
        }
        if lowerKey.contains("copilot") || lowerName.contains("copilot") || lowerOwned.contains("github") || lowerOwned.contains("copilot") {
            return .copilot
        }
        if lowerKey.contains("qwen") || lowerName.contains("qwen") || lowerOwned.contains("qwen") {
            return .qwen
        }
        if lowerKey.contains("codex") || lowerName.contains("codex") || lowerID.contains("codex") || lowerName.contains("openai") || lowerKey.contains("openai") || lowerOwned.contains("openai") {
            return .codex
        }
        return .other
    }
}

// Fetches available models per provider from the local proxy.
@MainActor
final class ModelCatalogFetcher: ObservableObject {
    struct Provider {
        let key: String
        let name: String
        let path: String
    }

    @Published var modelsByProvider: [String: [ModelEntry]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    let providers: [Provider] = [
        Provider(key: "openai", name: "OpenAI", path: "/api/provider/openai/models"),
        Provider(key: "anthropic", name: "Anthropic", path: "/api/provider/anthropic/models"),
        Provider(key: "google", name: "Google (v1)", path: "/api/provider/google/v1/models"),
        Provider(key: "google", name: "Google (v1beta)", path: "/api/provider/google/v1beta/models"),
        Provider(key: "groq", name: "Groq", path: "/api/provider/groq/models")
    ]

    func refresh(port: UInt16 = 8317) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let entries = try await withThrowingTaskGroup(of: [ModelEntry].self) { group in
                    for provider in providers {
                        group.addTask {
                            try await self.fetch(provider: provider, port: port)
                        }
                    }
                    var collected: [ModelEntry] = []
                    for try await entries in group {
                        collected.append(contentsOf: entries)
                    }
                    return collected
                }

                var buckets: [String: [ModelEntry]] = [:]
                for entry in entries {
                    var seen = buckets[entry.providerName, default: []]
                    if !seen.contains(where: { $0.id == entry.id && $0.providerKey == entry.providerKey }) {
                        seen.append(entry)
                        buckets[entry.providerName] = seen
                    }
                }
                modelsByProvider = buckets
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    private func fetch(provider: Provider, port: UInt16) async throws -> [ModelEntry] {
        guard let url = URL(string: "http://127.0.0.1:\(port)\(provider.path)") else {
            throw URLError(.badURL)
        }

        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return parseModels(data: data, fallbackProviderName: provider.name, fallbackProviderKey: provider.key)
    }

    private func parseModels(data: Data, fallbackProviderName: String, fallbackProviderKey: String) -> [ModelEntry] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        // Google returns "models", others typically use "data".
        let primaryArray = (object["models"] as? [[String: Any]]) ?? (object["data"] as? [[String: Any]]) ?? []

        return primaryArray.compactMap { item in
            let id = firstNonEmpty(
                item["id"],
                item["name"],
                item["model"],
                item["model_id"]
            )

            guard !id.isEmpty else { return nil }

            let display = firstNonEmpty(
                item["displayName"],
                item["display_name"],
                item["label"],
                item["description"]
            )

            let (providerDisplay, providerKey) = resolveProvider(from: item, fallbackName: fallbackProviderName, fallbackKey: fallbackProviderKey)
            let ownedBy = firstNonEmpty(item["owned_by"], item["provider"], item["type"])

            return ModelEntry(
                id: id,
                providerName: providerDisplay,
                providerKey: providerKey,
                label: display,
                ownedBy: ownedBy.isEmpty ? nil : ownedBy
            )
        }
    }

    private func resolveProvider(from item: [String: Any], fallbackName: String, fallbackKey: String) -> (String, String) {
        let raw = firstNonEmpty(item["type"], item["provider"], item["owned_by"])
        if raw.isEmpty { return (fallbackName, fallbackKey) }

        let normalized = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty { return (fallbackName, fallbackKey) }

        let lower = normalized.lowercased()
        if lower.contains("copilot") || lower.contains("github") {
            return ("GitHub Copilot", "copilot")
        }
        if lower.contains("groq") {
            return ("Groq", "groq")
        }
        if lower.contains("anthropic") || lower.contains("claude") {
            return ("Anthropic", "anthropic")
        }
        if lower.contains("google") || lower.contains("gemini") {
            return ("Google", "google")
        }
        if lower.contains("openai") {
            return ("OpenAI", "openai")
        }

        return (normalized.capitalized, fallbackKey)
    }

    private func firstNonEmpty(_ values: Any?...) -> String {
        for value in values {
            if let string = value as? String, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return string
            }
        }
        return ""
    }
}

struct ModelCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fetcher = ModelCatalogFetcher()
    @State private var query = ""
    @State private var expandedBuckets: Set<ServiceBucket> = Set(ServiceBucket.ordered)
    @FocusState private var filterFocused: Bool

    private func filteredModels() -> [(bucket: ServiceBucket, models: [ModelEntry])] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let allEntries = fetcher.modelsByProvider.values.flatMap { $0 }
        var buckets: [ServiceBucket: [ModelEntry]] = [:]

        guard !trimmed.isEmpty else {
            for entry in allEntries {
                let bucket = ServiceBucket.classify(providerKey: entry.providerKey, providerName: entry.providerName, ownedBy: entry.ownedBy, modelID: entry.id)
                buckets[bucket, default: []].append(entry)
            }
            return ServiceBucket.ordered.compactMap { b in
                guard let models = buckets[b], !models.isEmpty else { return nil }
                let sorted = models.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
                return (bucket: b, models: sorted)
            }
        }

        let normalizedQuery = normalize(trimmed)
        for entry in allEntries {
            if matches(entry.id, normalizedQuery: normalizedQuery) || matches(entry.displayLabel, normalizedQuery: normalizedQuery) {
                let bucket = ServiceBucket.classify(providerKey: entry.providerKey, providerName: entry.providerName, ownedBy: entry.ownedBy, modelID: entry.id)
                buckets[bucket, default: []].append(entry)
            }
        }

        return ServiceBucket.ordered.compactMap { b in
            guard let models = buckets[b], !models.isEmpty else { return nil }
            let sorted = models.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
            return (bucket: b, models: sorted)
        }
    }

    private func matches(_ text: String, normalizedQuery: String) -> Bool {
        let normalizedText = normalize(text)
        return normalizedText.contains(normalizedQuery)
    }

    private func normalize(_ text: String) -> String {
        let lower = text.lowercased()
        let allowed = CharacterSet.alphanumerics
        let filteredScalars = lower.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filteredScalars))
    }

    private func copyModelId(_ id: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(id, forType: .string)
    }

    private func copyCall(for entry: ModelEntry) {
        let provider = entry.providerKey.lowercased()
        let id = entry.id
        let call: String

        switch provider {
        case "anthropic":
            call = """
            curl -X POST http://127.0.0.1:8317/api/provider/anthropic/v1/messages \\
              -H "Content-Type: application/json" \\
              -H "Authorization: Bearer <token-if-required>" \\
              -d '{
                "model": "\(id)",
                "messages": [{"role":"user","content":"Hello"}]
              }'
            """
        case "google":
            let modelPath = id.hasPrefix("models/") ? id : "models/\(id)"
            call = """
            curl -X POST http://127.0.0.1:8317/api/provider/google/v1beta/\(modelPath):generateContent \\
              -H "Content-Type: application/json" \\
              -H "Authorization: Bearer <token-if-required>" \\
              -d '{
                "contents": [{"role":"user","parts":[{"text":"Hello"}]}]
              }'
            """
        case "groq", "openai", "copilot":
            fallthrough
        default:
            let routeProvider = provider == "copilot" ? "openai" : provider
            call = """
            curl -X POST http://127.0.0.1:8317/api/provider/\(routeProvider)/v1/chat/completions \\
              -H "Content-Type: application/json" \\
              -H "Authorization: Bearer <token-if-required>" \\
              -d '{
                "model": "\(id)",
                "messages": [{"role":"user","content":"Hello"}],
                "stream": false
              }'
            """
        }

        copyModelId(call)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Available models")
                    .font(.headline)
                Spacer()
                Button(action: { fetcher.refresh() }) {
                    if fetcher.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .help("Refresh from local proxy")
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }

            TextField("Filter models, e.g. opus-4.5", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($filterFocused)

            if let error = fetcher.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            let groups = filteredModels()
            if groups.allSatisfy({ $0.models.isEmpty }) && !fetcher.isLoading {
                Text("No models returned")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(groups, id: \.bucket) { group in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedBuckets.contains(group.bucket) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedBuckets.insert(group.bucket)
                                        } else {
                                            expandedBuckets.remove(group.bucket)
                                        }
                                    }
                                ),
                                content: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(group.models) { entry in
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(alignment: .top, spacing: 8) {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(entry.id)
                                                            .font(.callout)
                                                        if entry.displayLabel != entry.id {
                                                            Text(entry.displayLabel)
                                                                .font(.caption)
                                                                .foregroundColor(.secondary)
                                                        }
                                                        if let owned = entry.ownedBy {
                                                            Text(owned)
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                        }
                                                        Text(entry.displayProvider)
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                    Menu {
                                                        Button("Copy call") {
                                                            copyCall(for: entry)
                                                        }
                                                        Button("Copy model id") {
                                                            copyModelId(entry.id)
                                                        }
                                                    } label: {
                                                        Image(systemName: "doc.on.doc")
                                                    }
                                                    .menuStyle(.borderlessButton)
                                                    .help("Copy call or model id")
                                                }
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                    .padding(.top, 4)
                                },
                                label: {
                                    HStack {
                                        Text(group.bucket.rawValue)
                                        Spacer()
                                        Text("\(group.models.count)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(width: 440, height: 520)
        .onAppear {
            if fetcher.modelsByProvider.isEmpty {
                fetcher.refresh()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSApp.activate(ignoringOtherApps: true)
                filterFocused = true
            }
        }
    }
}
