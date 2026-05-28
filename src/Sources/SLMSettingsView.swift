import SwiftUI

// MARK: - Local Model Settings View
// Role-based configuration for local model instances

struct LocalModelSettingsView: View {
    @ObservedObject var modelManager: LocalModelManager
    @State private var selectedRole: ModelRole?
    @State private var showingAddInstance = false
    @State private var showingLogs = false
    @State private var searchQuery = ""
    @State private var searchResults: [DiscoveredModel] = []
    @State private var isSearching = false

    var body: some View {
        NavigationSplitView {
            // Sidebar: Role-based instances
            List(selection: $selectedRole) {
                Section("Active Instances") {
                    ForEach(ModelRole.allCases) { role in
                        if let instance = modelManager.getInstance(for: role) {
                            roleRow(role: role, instance: instance)
                                .tag(role)
                        }
                    }
                }

                Section("Available Roles") {
                    ForEach(ModelRole.allCases.filter { modelManager.getInstance(for: $0) == nil }) { role in
                        HStack {
                            Image(systemName: iconFor(role))
                                .foregroundColor(.secondary)
                            VStack(alignment: .leading) {
                                Text(role.displayName)
                                Text(role.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { addInstance(for: role) }) {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Discovered Models") {
                    if modelManager.isDiscovering {
                        HStack {
                            ProgressView().scaleEffect(0.7)
                            Text("Scanning...")
                        }
                    } else {
                        ForEach(modelManager.discoveredModels) { model in
                            discoveredModelRow(model)
                        }
                    }

                    Button(action: { modelManager.discoverInstalledModels() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 250)
            .toolbar {
                ToolbarItem {
                    Button(action: { showingLogs = true }) {
                        Image(systemName: "doc.text")
                    }
                }
            }
        } detail: {
            if let role = selectedRole, let instance = modelManager.getInstance(for: role) {
                instanceDetailView(instance: instance)
            } else {
                if #available(macOS 14.0, *) {
                    ContentUnavailableView("Select a Model Role",
                        systemImage: "cpu",
                        description: Text("Choose a role from the sidebar to configure"))
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "cpu")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Select a Model Role")
                            .font(.headline)
                        Text("Choose a role from the sidebar to configure")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showingLogs) { logsSheet }
        .sheet(isPresented: $showingAddInstance) { addInstanceSheet }
    }

    // MARK: - Row Views

    private func roleRow(role: ModelRole, instance: ModelInstanceConfig) -> some View {
        let status = modelManager.statuses[instance.id]
        return HStack {
            Image(systemName: iconFor(role))
                .foregroundColor(status?.running == true ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(role.displayName)
                    .fontWeight(.medium)
                Text(instance.model.components(separatedBy: "/").last ?? instance.model)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            statusBadge(status)
        }
    }

    private func discoveredModelRow(_ model: DiscoveredModel) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(model.name)
                HStack(spacing: 4) {
                    if let author = model.author {
                        Text(author).font(.caption2).foregroundColor(.secondary)
                    }
                    if model.isInstalled {
                        Text("Installed")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
            }
            Spacer()
            ForEach(model.recommendedRoles.prefix(2)) { role in
                Text(role.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }

    private func statusBadge(_ status: ModelInstanceStatus?) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status?.running == true ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            if status?.running == true {
                Text(":\(status?.port ?? 0)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Detail View

    private func instanceDetailView(instance: ModelInstanceConfig) -> some View {
        Form {
            Section("Status") {
                if let status = modelManager.statuses[instance.id] {
                    LabeledContent("State", value: status.running ? "Running" : "Stopped")
                    if status.running {
                        LabeledContent("Port", value: "\(status.port)")
                        if let latency = status.avgLatencyMs {
                            LabeledContent("Avg Latency", value: String(format: "%.1fms", latency))
                        }
                        LabeledContent("Requests", value: "\(status.requestsServed)")
                    }
                    if let error = status.error {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }

                HStack {
                    Button(action: { toggleInstance(instance) }) {
                        Label(modelManager.statuses[instance.id]?.running == true ? "Stop" : "Start",
                              systemImage: modelManager.statuses[instance.id]?.running == true ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(modelManager.statuses[instance.id]?.running == true ? .red : .green)
                }
            }

            Section("Configuration") {
                LabeledContent("Role", value: instance.role.displayName)
                LabeledContent("Backend", value: instance.backend.displayName)

                // Model picker with search
                DisclosureGroup("Model: \(instance.model.components(separatedBy: "/").last ?? instance.model)") {
                    TextField("Search models...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { performSearch(backend: instance.backend) }

                    if isSearching {
                        HStack { ProgressView().scaleEffect(0.7); Text("Searching...") }
                    }

                    ForEach(searchResults) { model in
                        Button(action: { selectModel(model, for: instance) }) {
                            HStack {
                                Text(model.name)
                                Spacer()
                                if let quant = model.quantization {
                                    Text(quant).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Recommended models for this role
                    Text("Recommended").font(.caption).foregroundColor(.secondary)
                    ForEach(instance.role.recommendedModels, id: \.self) { modelId in
                        Button(action: { selectModelById(modelId, for: instance) }) {
                            HStack {
                                Text(modelId.components(separatedBy: "/").last ?? modelId)
                                Spacer()
                                Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Server") {
                LabeledContent("Host", value: instance.host)
                LabeledContent("Port", value: "\(instance.port)")
                LabeledContent("Max Context", value: "\(instance.maxContextLength)")
                Toggle("Enabled", isOn: .constant(instance.enabled))
                Toggle("Auto-start", isOn: .constant(instance.autoStart))
            }

            Section {
                Button(role: .destructive, action: { modelManager.removeInstance(instance.id) }) {
                    Label("Remove Instance", systemImage: "trash")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(instance.role.displayName)
    }

    // MARK: - Sheets

    private var logsSheet: some View {
        VStack {
            HStack {
                Text("Model Logs").font(.headline)
                Spacer()
                Button("Clear") { modelManager.clearLogs() }
                Button("Close") { showingLogs = false }
            }
            .padding()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(modelManager.logs, id: \.self) { log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.9))
            .foregroundColor(.green)
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var addInstanceSheet: some View {
        Text("Add Instance") // TODO: Implement add instance form
    }

    // MARK: - Helpers

    private func iconFor(_ role: ModelRole) -> String {
        switch role {
        case .modelRouter: return "arrow.triangle.branch"
        case .toolRouter: return "wrench.and.screwdriver"
        case .taskClassifier: return "tag"
        case .summarizer: return "doc.text.magnifyingglass"
        case .codeAssistant: return "chevron.left.forwardslash.chevron.right"
        case .reasoner: return "brain"
        case .embedder: return "cube.transparent"
        case .sentimentAnalyzer: return "face.smiling"
        case .contentModerator: return "shield.checkered"
        case .custom: return "gearshape"
        }
    }

    private func addInstance(for role: ModelRole) {
        let config = ModelInstanceConfig.defaultFor(role: role)
        modelManager.addInstance(config)
    }

    private func toggleInstance(_ instance: ModelInstanceConfig) {
        if modelManager.statuses[instance.id]?.running == true {
            modelManager.stop(instance.id)
        } else {
            modelManager.start(instance.id) { _ in }
        }
    }

    private func performSearch(backend: InferenceBackend) {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        modelManager.searchModels(query: searchQuery, backend: backend) { results in
            searchResults = results
            isSearching = false
        }
    }

    private func selectModel(_ model: DiscoveredModel, for instance: ModelInstanceConfig) {
        var updated = instance
        updated.model = model.id
        modelManager.updateInstance(updated)
    }

    private func selectModelById(_ modelId: String, for instance: ModelInstanceConfig) {
        var updated = instance
        updated.model = modelId
        modelManager.updateInstance(updated)
    }
}

// MARK: - Legacy Alias
typealias SLMSettingsView = LocalModelSettingsView

// MARK: - Preview

#Preview {
    LocalModelSettingsView(modelManager: LocalModelManager.shared)
        .frame(width: 700, height: 600)
}

