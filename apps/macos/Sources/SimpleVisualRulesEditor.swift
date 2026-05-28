import SwiftUI
import Inject

struct SimpleVisualRulesEditor: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var serverManager: ServerManager
    @StateObject private var serviceDiscoveryManager = ServiceDiscoveryManager.shared

    @State private var rules: [RuleInfo] = []
    @State private var recommendedModels: [ModelRecommendation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAlert = false

    init(serverManager: ServerManager) {
        self._serverManager = StateObject(wrappedValue: serverManager)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading rules and recommendations from CLIProxyAPI...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.controlBackgroundColor))
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Could not load rules")
                            .font(.headline)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadRulesAndModels()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.controlBackgroundColor))
                } else {
                    VStack(spacing: 0) {
                        // Header
                        headerSection

                        // Main content
                        ScrollView {
                            VStack(spacing: 20) {
                                // Available Services
                                if !serviceDiscoveryManager.services.isEmpty {
                                    servicesSection
                                }

                                // Generated Rules
                                if !rules.isEmpty {
                                    rulesSection
                                }

                                // Recommended Models
                                if !recommendedModels.isEmpty {
                                    modelsSection
                                }

                                if rules.isEmpty && recommendedModels.isEmpty {
                                    emptyStateView
                                }
                            }
                            .padding(20)
                        }

                        // Action buttons
                        actionButtons
                    }
                }
            }
            .navigationTitle("Visual Rules Editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 600)
        .onAppear {
            loadRulesAndModels()
        }
        .enableInjection()
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Intelligent Request Routing")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Real-time rules and recommendations from CLIProxyAPI learning system")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.secondary.opacity(0.05))
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Services")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                ForEach(serviceDiscoveryManager.services, id: \.id) { service in
                    VStack(spacing: 8) {
                        if let iconName = service.icon,
                           let nsImage = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 24, height: 24), template: true) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                        }
                        Text(service.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        Text("\(service.modelCount) models")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generated Rules (\(rules.count))")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(rules.indices, id: \.self) { idx in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rules[idx].name)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            if rules[idx].isActive {
                                Label("Active", systemImage: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        if let description = rules[idx].description {
                            Text(description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Models")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(recommendedModels.prefix(5).indices, id: \.self) { idx in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recommendedModels[idx].modelName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(recommendedModels[idx].provider)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let score = recommendedModels[idx].score {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text(String(format: "%.1f", score))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No rules or recommendations yet")
                .font(.headline)
            Text("Use CLIProxyAPI to generate rules based on usage patterns")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Refresh") {
                loadRulesAndModels()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(Color(.controlBackgroundColor))
    }

    private func loadRulesAndModels() {
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()
        var rulesData: [String: Any]?
        var modelsData: [[String: Any]]?
        var rulesError: Error?
        var modelsError: Error?

        // Load rules
        group.enter()
        CLIProxyAPI.shared.getGeneratedRules { data, error in
            rulesData = data
            rulesError = error
            group.leave()
        }

        // Load recommended models
        group.enter()
        CLIProxyAPI.shared.getRecommendedModels { data, error in
            modelsData = data
            modelsError = error
            group.leave()
        }

        group.notify(queue: .main) {
            self.isLoading = false

            // Parse rules
            if let rulesData = rulesData {
                self.rules = self.parseRules(rulesData)
            } else if let error = rulesError {
                self.errorMessage = "Failed to load rules: \(error.localizedDescription)"
            }

            // Parse models
            if let modelsData = modelsData {
                self.recommendedModels = self.parseModels(modelsData)
            } else if let error = modelsError {
                self.errorMessage = "Failed to load recommendations: \(error.localizedDescription)"
            }

            if self.rules.isEmpty && self.recommendedModels.isEmpty && self.errorMessage == nil {
                self.errorMessage = "No data received from CLIProxyAPI"
            }
        }
    }

    private func parseRules(_ data: [String: Any]) -> [RuleInfo] {
        var rules: [RuleInfo] = []

        if let rulesList = data["rules"] as? [[String: Any]] {
            for ruleData in rulesList {
                let rule = RuleInfo(
                    id: ruleData["id"] as? String ?? UUID().uuidString,
                    name: ruleData["name"] as? String ?? "Unknown Rule",
                    description: ruleData["description"] as? String,
                    isActive: ruleData["active"] as? Bool ?? false,
                    confidence: ruleData["confidence"] as? Double
                )
                rules.append(rule)
            }
        }

        return rules
    }

    private func parseModels(_ data: [[String: Any]]) -> [ModelRecommendation] {
        var models: [ModelRecommendation] = []

        for modelData in data {
            let model = ModelRecommendation(
                modelName: modelData["model"] as? String ?? "Unknown",
                provider: modelData["provider"] as? String ?? "Unknown",
                score: modelData["score"] as? Double
            )
            models.append(model)
        }

        return models
    }
}

struct RuleInfo {
    let id: String
    let name: String
    let description: String?
    let isActive: Bool
    let confidence: Double?
}

struct ModelRecommendation {
    let modelName: String
    let provider: String
    let score: Double?
}
