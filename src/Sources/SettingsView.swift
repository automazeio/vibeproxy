import SwiftUI
import ServiceManagement

// MARK: - Models API Types

fileprivate struct ModelInfo: Decodable, Identifiable {
    let id: String
    let owned_by: String
}

fileprivate struct ModelsResponse: Decodable {
    let data: [ModelInfo]
}

/// A single account row with enable/disable toggle and remove button
struct AccountRowView: View {
    let account: AuthAccount
    let removeColor: Color
    let isDisabled: Bool
    let disableReason: String?
    let onRemove: () -> Void
    let onToggleEnabled: (Bool) -> Void

    init(account: AuthAccount, removeColor: Color, isDisabled: Bool = false, disableReason: String? = nil,
         onRemove: @escaping () -> Void, onToggleEnabled: @escaping (Bool) -> Void = { _ in }) {
        self.account = account
        self.removeColor = removeColor
        self.isDisabled = isDisabled
        self.disableReason = disableReason
        self.onRemove = onRemove
        self.onToggleEnabled = onToggleEnabled
    }

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { !isDisabled },
                set: { onToggleEnabled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()

            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(account.displayName)
                .font(.caption)
                .foregroundColor(isDisabled ? .gray : (account.isExpired ? .orange : .secondary))
            if account.isExpired {
                Text("(expired)")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            if let reason = disableReason {
                Text("(\(reason))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Button(action: onRemove) {
                HStack(spacing: 2) {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption)
                    Text("Remove")
                        .font(.caption)
                }
                .foregroundColor(removeColor)
            }
            .buttonStyle(.plain)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.leading, 28)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    private var statusColor: Color {
        if isDisabled { return .gray }
        if account.isExpired { return .orange }
        return .green
    }
}

/// Provider usage pills shown per-account in expanded section
struct ProviderUsageRow: View {
    let usage: ProviderUsageData?

    var body: some View {
        HStack(spacing: 6) {
            if let usage = usage {
                switch usage.status {
                case .loading:
                    ProgressView()
                        .controlSize(.mini)
                    Text("Checking usage...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .loaded:
                    usagePills(usage)
                case .invalidCredentials:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("Invalid credentials")
                        .font(.caption2)
                        .foregroundColor(.red)
                case .error(let msg):
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.leading, 42)
    }

    @ViewBuilder
    private func usagePills(_ usage: ProviderUsageData) -> some View {
        if let remaining = usage.primaryRemainingPercent {
            pillView(percent: remaining, label: "left", reset: usage.primaryResetFormatted, color: pillColor(remaining))
        }
        if let remaining = usage.secondaryRemainingPercent {
            pillView(percent: remaining, label: "weekly", reset: usage.secondaryResetFormatted, color: pillColor(remaining))
        }
    }

    private func pillView(percent: Int, label: String, reset: String?, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(percent)% \(label)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
            if let reset = reset {
                Text("(\(reset))")
                    .font(.system(size: 9, design: .monospaced))
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(3)
    }

    private func pillColor(_ percent: Int) -> Color {
        if percent > 50 { return .green }
        if percent > 20 { return .orange }
        return .red
    }
}

/// Vercel AI Gateway controls shown in Claude expanded section
struct VercelGatewayControls: View {
    @ObservedObject var serverManager: ServerManager
    @State private var showingSaved = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $serverManager.vercelGatewayEnabled) {
                Text("Use Vercel AI Gateway")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Route Claude requests through Vercel AI Gateway for safer access to your Claude Max subscription")
            
            if serverManager.vercelGatewayEnabled {
                HStack(spacing: 8) {
                    Text("Vercel API key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("", text: $serverManager.vercelApiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                        .font(.caption)
                    
                    if showingSaved {
                        Text("Saved")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Button("Save") {
                            showingSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showingSaved = false
                            }
                        }
                        .controlSize(.small)
                        .disabled(serverManager.vercelApiKey.isEmpty)
                    }
                }
            }
        }
        .padding(.leading, 28)
        .padding(.top, 4)
    }
}

/// A row displaying a service with its connected accounts and add button
struct ServiceRow<ExtraContent: View, AccountContent: View>: View {
    let serviceType: ServiceType
    let iconName: String
    let accounts: [AuthAccount]
    let disabledAccounts: [AuthAccount]
    let autoDisabledAccounts: [AuthAccount]
    let isAuthenticating: Bool
    let helpText: String?
    let isEnabled: Bool
    let customTitle: String?
    let onConnect: () -> Void
    let onDisconnect: (AuthAccount) -> Void
    let onToggleEnabled: (Bool) -> Void
    let onToggleAccountEnabled: (AuthAccount, Bool) -> Void
    var onExpandChange: ((Bool) -> Void)? = nil
    @ViewBuilder var extraContent: () -> ExtraContent
    @ViewBuilder var accountContent: (AuthAccount) -> AccountContent

    @State private var isExpanded = false
    @State private var accountToRemove: AuthAccount?
    @State private var showingRemoveConfirmation = false

    private var allAccounts: [AuthAccount] { accounts + disabledAccounts + autoDisabledAccounts }
    private var activeCount: Int { accounts.filter { !$0.isExpired }.count }
    private var expiredCount: Int { accounts.filter { $0.isExpired }.count }
    private let removeColor = Color(red: 0xeb/255, green: 0x0f/255, blue: 0x0f/255)
    
    private var displayTitle: String {
        customTitle ?? serviceType.displayName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header row
            HStack {
                // Enable/disable toggle
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { onToggleEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(isEnabled ? "Disable this provider" : "Enable this provider")

                if let nsImage = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 20, height: 20), template: true) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .opacity(isEnabled ? 1.0 : 0.4)
                }
                Text(displayTitle)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                Spacer()
                if isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                } else if isEnabled {
                    Button("Add Account") {
                        onConnect()
                    }
                    .controlSize(.small)
                }
            }
            
            // Account display (only shown when enabled)
            if isEnabled {
                if !allAccounts.isEmpty {
                    // Collapsible summary
                    HStack(spacing: 4) {
                        let totalCount = allAccounts.count
                        let disabledCount = disabledAccounts.count + autoDisabledAccounts.count
                        Text("\(totalCount) account\(totalCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.green)
                        if disabledCount > 0 {
                            Text("• \(disabledCount) paused")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        if activeCount > 1 {
                            Text("• Round-robin w/ auto-failover")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 28)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }

                    // Expanded accounts list
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            // Active accounts
                            ForEach(accounts) { account in
                                VStack(alignment: .leading, spacing: 2) {
                                    AccountRowView(account: account, removeColor: removeColor, onRemove: {
                                        accountToRemove = account
                                        showingRemoveConfirmation = true
                                    }, onToggleEnabled: { enabled in
                                        onToggleAccountEnabled(account, enabled)
                                    })
                                    accountContent(account)
                                }
                            }
                            // Manually disabled accounts
                            ForEach(disabledAccounts) { account in
                                AccountRowView(account: account, removeColor: removeColor,
                                               isDisabled: true, disableReason: "disabled",
                                               onRemove: {
                                    accountToRemove = account
                                    showingRemoveConfirmation = true
                                }, onToggleEnabled: { enabled in
                                    onToggleAccountEnabled(account, enabled)
                                })
                            }
                            // Auto-disabled accounts (depleted)
                            ForEach(autoDisabledAccounts) { account in
                                AccountRowView(account: account, removeColor: removeColor,
                                               isDisabled: true, disableReason: "no credits",
                                               onRemove: {
                                    accountToRemove = account
                                    showingRemoveConfirmation = true
                                }, onToggleEnabled: { enabled in
                                    onToggleAccountEnabled(account, enabled)
                                })
                            }
                            extraContent()
                        }
                        .padding(.top, 4)
                    }
                } else {
                    Text("No connected accounts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                }
            }
        }
        .padding(.vertical, 4)
        .help(helpText ?? "")
        .onAppear {
            if accounts.contains(where: { $0.isExpired }) {
                isExpanded = true
            }
        }
        .onChange(of: accounts) { newAccounts in
            if newAccounts.contains(where: { $0.isExpired }) {
                isExpanded = true
            }
        }
        .onChange(of: isExpanded) { newValue in
            onExpandChange?(newValue)
        }
        .alert("Remove Account", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) {
                accountToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let account = accountToRemove {
                    onDisconnect(account)
                }
                accountToRemove = nil
            }
        } message: {
            if let account = accountToRemove {
                Text("Are you sure you want to remove \(account.displayName) from \(serviceType.displayName)?")
            }
        }
    }
}

// Default accountContent = EmptyView for call sites that don't need per-account content
extension ServiceRow where AccountContent == EmptyView {
    init(
        serviceType: ServiceType, iconName: String, accounts: [AuthAccount],
        disabledAccounts: [AuthAccount] = [], autoDisabledAccounts: [AuthAccount] = [],
        isAuthenticating: Bool, helpText: String?, isEnabled: Bool, customTitle: String?,
        onConnect: @escaping () -> Void, onDisconnect: @escaping (AuthAccount) -> Void,
        onToggleEnabled: @escaping (Bool) -> Void,
        onToggleAccountEnabled: @escaping (AuthAccount, Bool) -> Void = { _, _ in },
        onExpandChange: ((Bool) -> Void)? = nil,
        @ViewBuilder extraContent: @escaping () -> ExtraContent
    ) {
        self.serviceType = serviceType; self.iconName = iconName; self.accounts = accounts
        self.disabledAccounts = disabledAccounts; self.autoDisabledAccounts = autoDisabledAccounts
        self.isAuthenticating = isAuthenticating; self.helpText = helpText; self.isEnabled = isEnabled
        self.customTitle = customTitle; self.onConnect = onConnect; self.onDisconnect = onDisconnect
        self.onToggleEnabled = onToggleEnabled; self.onToggleAccountEnabled = onToggleAccountEnabled
        self.onExpandChange = onExpandChange
        self.extraContent = extraContent; self.accountContent = { _ in EmptyView() }
    }
}

fileprivate struct ModelGroupRow: View {
    @Binding var group: ModelGroup
    let onDelete: () -> Void
    let availableModels: [String: [ModelInfo]]
    @State private var showingModelPicker = false

    private static let providerColors: [String: Color] = [
        "anthropic": .orange, "openai": .green, "github-copilot": .purple,
        "google": .blue, "qwen": .cyan, "zai": .yellow,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: toggle + name field + delete
            HStack(spacing: 8) {
                Toggle("", isOn: $group.enabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()

                TextField("Enter group name", text: $group.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Delete group")
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }

            if group.enabled {
                // Models list
                VStack(alignment: .leading, spacing: 0) {
                    if group.models.isEmpty {
                        HStack {
                            Text("No models added yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                    } else {
                        ForEach(group.models.indices, id: \.self) { index in
                            HStack(spacing: 6) {
                                // Provider pill
                                let parts = splitQualified(group.models[index])
                                if let provider = parts.provider {
                                    Text(provider)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Self.providerColors[provider] ?? .secondary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background((Self.providerColors[provider] ?? .secondary).opacity(0.12))
                                        .cornerRadius(4)
                                }

                                Text(parts.modelId)
                                    .font(.system(size: 11, design: .monospaced))

                                Spacer()

                                Button(action: { group.models.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .onHover { inside in
                                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)

                            if index < group.models.count - 1 {
                                Divider().padding(.leading, 8)
                            }
                        }
                    }

                    // Add model row
                    Button(action: { showingModelPicker.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Add Model")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    .popover(isPresented: $showingModelPicker, arrowEdge: .bottom) {
                        ModelPickerPopover(
                            availableModels: availableModels,
                            alreadyAdded: Set(group.models),
                            onSelect: { qualifiedName in
                                group.models.append(qualifiedName)
                                showingModelPicker = false
                            }
                        )
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )

                if group.models.count > 1 {
                    Text("Requests round-robin across models with auto-failover")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func splitQualified(_ qualified: String) -> (provider: String?, modelId: String) {
        guard let idx = qualified.firstIndex(of: "/") else { return (nil, qualified) }
        return (String(qualified[..<idx]), String(qualified[qualified.index(after: idx)...]))
    }
}

private struct ModelPickerPopover: View {
    let availableModels: [String: [ModelInfo]]
    let alreadyAdded: Set<String>
    let onSelect: (String) -> Void
    @State private var searchText = ""
    @State private var hoveredModel: String?

    private static let providerDisplayNames: [String: String] = [
        "anthropic": "Anthropic", "openai": "OpenAI", "github-copilot": "GitHub Copilot",
        "google": "Google", "qwen": "Qwen", "zai": "Z.AI",
    ]

    private var filteredModels: [(provider: String, models: [ModelInfo])] {
        let search = searchText.lowercased()
        return availableModels.keys.sorted().compactMap { provider in
            let models = availableModels[provider]?.filter { model in
                let qualifiedName = "\(provider)/\(model.id)"
                if alreadyAdded.contains(qualifiedName) { return false }
                if search.isEmpty { return true }
                return model.id.lowercased().contains(search) || provider.lowercased().contains(search)
            } ?? []
            return models.isEmpty ? nil : (provider: provider, models: models)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Search models...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if filteredModels.isEmpty {
                        Text("No matching models")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(filteredModels, id: \.provider) { group in
                            HStack(spacing: 5) {
                                Text(Self.providerDisplayNames[group.provider] ?? group.provider.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                                Text("\(group.models.count)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 10)
                            .padding(.bottom, 4)

                            ForEach(group.models) { model in
                                let qualifiedName = "\(group.provider)/\(model.id)"
                                Button(action: {
                                    onSelect(qualifiedName)
                                }) {
                                    HStack(spacing: 0) {
                                        Text(model.id)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if hoveredModel == qualifiedName {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(hoveredModel == qualifiedName ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { inside in
                                    hoveredModel = inside ? qualifiedName : nil
                                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .frame(width: 300, height: 340)
    }
}

struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @ObservedObject var authManager: AuthManager
    @ObservedObject var codexUsageManager: CodexUsageManager
    @ObservedObject var claudeUsageManager: ClaudeUsageManager
    @State private var launchAtLogin = false
    @State private var authenticatingService: ServiceType? = nil
    @State private var showingAuthResult = false
    @State private var authResultMessage = ""
    @State private var authResultSuccess = false
    @State private var fileMonitor: DispatchSourceFileSystemObject?
    @State private var showingQwenEmailPrompt = false
    @State private var qwenEmail = ""
    @State private var showingZaiApiKeyPrompt = false
    @State private var zaiApiKey = ""
    @State private var pendingRefresh: DispatchWorkItem?
    @State private var expandedRowCount = 0
    @State private var availableModels: [String: [ModelInfo]] = [:]
    @State private var modelsLoading = false
    @State private var modelsError: String?
    @State private var copiedModelId: String?
    
    private enum Timing {
        static let serverRestartDelay: TimeInterval = 0.3
        static let refreshDebounce: TimeInterval = 0.5
    }

    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "v\(version)"
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        Text("Server status")
                        Spacer()
                        Button(action: {
                            if serverManager.isRunning {
                                serverManager.stop()
                            } else {
                                serverManager.start { _ in }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(serverManager.isRunning ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(serverManager.isRunning ? "Running" : "Stopped")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            toggleLaunchAtLogin(newValue)
                        }

                    HStack {
                        Text("Auth files")
                        Spacer()
                        Button("Open Folder") {
                            openAuthFolder()
                        }
                    }
                }

                Section("Services") {
                    ServiceRow(
                        serviceType: .antigravity,
                        iconName: "icon-antigravity.png",
                        accounts: authManager.accounts(for: .antigravity),
                        disabledAccounts: authManager.manuallyDisabledAccounts.filter { $0.type == .antigravity },
                        autoDisabledAccounts: authManager.autoDisabledAccounts.filter { $0.type == .antigravity },
                        isAuthenticating: authenticatingService == .antigravity,
                        helpText: "Antigravity provides OAuth-based access to various AI models including Gemini and Claude. One login gives you access to multiple AI services.",
                        isEnabled: serverManager.isProviderEnabled("antigravity"),
                        customTitle: nil,
                        onConnect: { connectService(.antigravity) },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("antigravity", enabled: enabled) },
                        onToggleAccountEnabled: { account, enabled in toggleAccountEnabled(account, enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                    ServiceRow(
                        serviceType: .claude,
                        iconName: "icon-claude.png",
                        accounts: authManager.accounts(for: .claude),
                        disabledAccounts: authManager.manuallyDisabledAccounts.filter { $0.type == .claude },
                        autoDisabledAccounts: authManager.autoDisabledAccounts.filter { $0.type == .claude },
                        isAuthenticating: authenticatingService == .claude,
                        helpText: nil,
                        isEnabled: serverManager.isProviderEnabled("claude"),
                        customTitle: serverManager.vercelGatewayEnabled && !serverManager.vercelApiKey.isEmpty ? "Claude Code (via Vercel)" : nil,
                        onConnect: { connectService(.claude) },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("claude", enabled: enabled) },
                        onToggleAccountEnabled: { account, enabled in toggleAccountEnabled(account, enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 },
                        extraContent: { VercelGatewayControls(serverManager: serverManager) }
                    ) { account in
                        if !account.isExpired {
                            ProviderUsageRow(usage: claudeUsageManager.usage(for: account.id))
                        }
                    }

                    ServiceRow(
                        serviceType: .codex,
                        iconName: "icon-codex.png",
                        accounts: authManager.accounts(for: .codex),
                        disabledAccounts: authManager.manuallyDisabledAccounts.filter { $0.type == .codex },
                        autoDisabledAccounts: authManager.autoDisabledAccounts.filter { $0.type == .codex },
                        isAuthenticating: authenticatingService == .codex,
                        helpText: nil,
                        isEnabled: serverManager.isProviderEnabled("codex"),
                        customTitle: nil,
                        onConnect: { connectService(.codex) },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("codex", enabled: enabled) },
                        onToggleAccountEnabled: { account, enabled in toggleAccountEnabled(account, enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 },
                        extraContent: { EmptyView() }
                    ) { account in
                        if !account.isExpired {
                            ProviderUsageRow(usage: codexUsageManager.usage(for: account.id))
                        }
                    }

                    ServiceRow(
                        serviceType: .gemini,
                        iconName: "icon-gemini.png",
                        accounts: authManager.accounts(for: .gemini),
                        disabledAccounts: authManager.manuallyDisabledAccounts.filter { $0.type == .gemini },
                        autoDisabledAccounts: authManager.autoDisabledAccounts.filter { $0.type == .gemini },
                        isAuthenticating: authenticatingService == .gemini,
                        helpText: "⚠️ Note: If you're an existing Gemini user with multiple projects, authentication will use your default project. Set your desired project as default in Google AI Studio before connecting.",
                        isEnabled: serverManager.isProviderEnabled("gemini"),
                        customTitle: nil,
                        onConnect: { connectService(.gemini) },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("gemini", enabled: enabled) },
                        onToggleAccountEnabled: { account, enabled in toggleAccountEnabled(account, enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                    ServiceRow(
                        serviceType: .copilot,
                        iconName: "icon-copilot.png",
                        accounts: authManager.accounts(for: .copilot),
                        disabledAccounts: authManager.manuallyDisabledAccounts.filter { $0.type == .copilot },
                        autoDisabledAccounts: authManager.autoDisabledAccounts.filter { $0.type == .copilot },
                        isAuthenticating: authenticatingService == .copilot,
                        helpText: "GitHub Copilot provides access to Claude, GPT, Gemini and other models via your Copilot subscription.",
                        isEnabled: serverManager.isProviderEnabled("github-copilot"),
                        customTitle: nil,
                        onConnect: { connectService(.copilot) },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("github-copilot", enabled: enabled) },
                        onToggleAccountEnabled: { account, enabled in toggleAccountEnabled(account, enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                    ServiceRow(
                        serviceType: .qwen,
                        iconName: "icon-qwen.png",
                        accounts: authManager.accounts(for: .qwen),
                        disabledAccounts: authManager.manuallyDisabledAccounts.filter { $0.type == .qwen },
                        autoDisabledAccounts: authManager.autoDisabledAccounts.filter { $0.type == .qwen },
                        isAuthenticating: authenticatingService == .qwen,
                        helpText: nil,
                        isEnabled: serverManager.isProviderEnabled("qwen"),
                        customTitle: nil,
                        onConnect: { showingQwenEmailPrompt = true },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("qwen", enabled: enabled) },
                        onToggleAccountEnabled: { account, enabled in toggleAccountEnabled(account, enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                    ServiceRow(
                        serviceType: .zai,
                        iconName: "icon-zai.png",
                        accounts: authManager.accounts(for: .zai),
                        disabledAccounts: authManager.manuallyDisabledAccounts.filter { $0.type == .zai },
                        autoDisabledAccounts: authManager.autoDisabledAccounts.filter { $0.type == .zai },
                        isAuthenticating: authenticatingService == .zai,
                        helpText: "Z.AI GLM provides access to GLM-4.7 and other models via API key. Get your key at https://z.ai/manage-apikey/apikey-list",
                        isEnabled: serverManager.isProviderEnabled("zai"),
                        customTitle: nil,
                        onConnect: { showingZaiApiKeyPrompt = true },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("zai", enabled: enabled) },
                        onToggleAccountEnabled: { account, enabled in toggleAccountEnabled(account, enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                }

                Section("Model Groups") {
                    if serverManager.modelGroups.isEmpty {
                        VStack(spacing: 4) {
                            Text("Create a virtual model that round-robins across multiple real models with auto-failover.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        ForEach($serverManager.modelGroups) { $group in
                            ModelGroupRow(group: $group, onDelete: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    serverManager.modelGroups.removeAll { $0.id == group.id }
                                }
                            }, availableModels: availableModels)
                            if group.id != serverManager.modelGroups.last?.id {
                                Divider()
                            }
                        }
                    }

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            serverManager.modelGroups.append(ModelGroup())
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                            Text("New Group")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                Section("Available Models") {
                    if modelsLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading models...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let error = modelsError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if availableModels.isEmpty {
                        Text("No models available — connect a service above")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(availableModels.keys.sorted(), id: \.self) { provider in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: providerIcon(provider))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(providerDisplayName(provider))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("\(availableModels[provider]?.count ?? 0)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(3)
                                }

                                if let models = availableModels[provider] {
                                    VStack(alignment: .leading, spacing: 3) {
                                        ForEach(models) { model in
                                            Button(action: {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(model.id, forType: .string)
                                                copiedModelId = model.id
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                    if copiedModelId == model.id { copiedModelId = nil }
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Text(model.id)
                                                        .font(.system(size: 11, design: .monospaced))
                                                        .foregroundColor(.primary)
                                                    if copiedModelId == model.id {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 9, weight: .semibold))
                                                            .foregroundColor(.green)
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            .help("Click to copy")
                                        }
                                    }
                                    .padding(.leading, 22)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .environmentObject(codexUsageManager)

            Spacer()
                .frame(height: 6)

            // Footer
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("VibeProxy \(appVersion) was made possible thanks to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("CLIProxyAPIPlus", destination: URL(string: "https://github.com/router-for-me/CLIProxyAPIPlus")!)
                        .font(.caption)
                        .underline()
                        .foregroundColor(.secondary)
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    Text("|")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("License: MIT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Text("© 2026")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("Automaze, Ltd.", destination: URL(string: "https://automaze.io")!)
                        .font(.caption)
                        .underline()
                        .foregroundColor(.secondary)
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    Text("All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Link("Report an issue", destination: URL(string: "https://github.com/automazeio/vibeproxy/issues")!)
                    .font(.caption)
                    .padding(.top, 6)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            }
            .padding(.bottom, 12)
        }
        .frame(width: 480, height: 860)
        .sheet(isPresented: $showingQwenEmailPrompt) {
            VStack(spacing: 16) {
                Text("Qwen Account Email")
                    .font(.headline)
                Text("Enter your Qwen account email address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("your.email@example.com", text: $qwenEmail)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingQwenEmailPrompt = false
                        qwenEmail = ""
                    }
                    Button("Continue") {
                        showingQwenEmailPrompt = false
                        startQwenAuth(email: qwenEmail)
                    }
                    .disabled(qwenEmail.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 350)
        }
        .sheet(isPresented: $showingZaiApiKeyPrompt) {
            VStack(spacing: 16) {
                Text("Z.AI API Key")
                    .font(.headline)
                Text("Enter your Z.AI API key from https://z.ai/manage-apikey/apikey-list")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $zaiApiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingZaiApiKeyPrompt = false
                        zaiApiKey = ""
                    }
                    Button("Add Key") {
                        showingZaiApiKeyPrompt = false
                        startZaiAuth(apiKey: zaiApiKey)
                    }
                    .disabled(zaiApiKey.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 400)
        }
        .onAppear {
            checkLaunchAtLogin()
            startMonitoringAuthDirectory()
            if serverManager.isRunning { fetchModels() }
        }
        .onChange(of: serverManager.isRunning) { _, running in
            if running {
                // Small delay to let server fully start
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { fetchModels() }
            } else {
                availableModels = [:]
                modelsError = nil
            }
        }
        .onDisappear {
            stopMonitoringAuthDirectory()
        }
        .alert("Authentication Result", isPresented: $showingAuthResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authResultMessage)
        }
    }

    // MARK: - Actions
    
    private func openAuthFolder() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        NSWorkspace.shared.open(authDir)
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("[SettingsView] Failed to toggle launch at login: %@", error.localizedDescription)
            }
        }
    }

    private func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func connectService(_ serviceType: ServiceType) {
        authenticatingService = serviceType
        NSLog("[SettingsView] Starting %@ authentication", serviceType.displayName)
        
        let command: AuthCommand
        switch serviceType {
        case .claude: command = .claudeLogin
        case .codex: command = .codexLogin
        case .copilot: command = .copilotLogin
        case .gemini: command = .geminiLogin
        case .qwen:
            authenticatingService = nil
            return // handled separately with email prompt
        case .antigravity: command = .antigravityLogin
        case .zai:
            authenticatingService = nil
            return // handled separately with API key prompt
        }
        
        serverManager.runAuthCommand(command) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.authenticatingService = nil
                
                if success {
                    self.authResultSuccess = true
                    // For Copilot, use the output which contains the device code
                    if serviceType == .copilot && (output.contains("Code copied") || output.contains("code:")) {
                        self.authResultMessage = output
                    } else {
                        self.authResultMessage = self.successMessage(for: serviceType)
                    }
                    self.showingAuthResult = true
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }
    
    private func successMessage(for serviceType: ServiceType) -> String {
        switch serviceType {
        case .claude:
            return "🌐 Browser opened for Claude Code authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect your credentials."
        case .codex:
            return "🌐 Browser opened for Codex authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect your credentials."
        case .copilot:
            return "🌐 GitHub Copilot authentication started!\n\nPlease visit github.com/login/device and enter the code shown.\n\nThe app will automatically detect your credentials."
        case .gemini:
            return "🌐 Browser opened for Gemini authentication.\n\nPlease complete the login in your browser.\n\n⚠️ Note: If you have multiple projects, the default project will be used."
        case .qwen:
            return "🌐 Browser opened for Qwen authentication.\n\nPlease complete the login in your browser."
        case .antigravity:
            return "🌐 Browser opened for Antigravity authentication.\n\nPlease complete the login in your browser."
        case .zai:
            return "✓ Z.AI API key added successfully.\n\nYou can now use GLM models through the proxy."
        }
    }
    
    private func startQwenAuth(email: String) {
        authenticatingService = .qwen
        NSLog("[SettingsView] Starting Qwen authentication")
        
        serverManager.runAuthCommand(.qwenLogin(email: email)) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.authenticatingService = nil
                self.qwenEmail = ""
                
                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = self.successMessage(for: .qwen)
                    self.showingAuthResult = true
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed.\n\nDetails: \(output.isEmpty ? "No output" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }
    
    private func startZaiAuth(apiKey: String) {
        authenticatingService = .zai
        NSLog("[SettingsView] Adding Z.AI API key")
        
        serverManager.saveZaiApiKey(apiKey) { success, output in
            NSLog("[SettingsView] Z.AI key save completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.authenticatingService = nil
                self.zaiApiKey = ""
                
                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = self.successMessage(for: .zai)
                    self.showingAuthResult = true
                    self.authManager.checkAuthStatus()
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Failed to save API key.\n\nDetails: \(output.isEmpty ? "Unknown error" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }
    
    private func toggleAccountEnabled(_ account: AuthAccount, enabled: Bool) {
        let wasRunning = serverManager.isRunning

        let action = {
            let success: Bool
            if enabled {
                // Re-enable: check both manual and auto-disabled
                if self.authManager.isManuallyDisabled(account) {
                    success = self.authManager.enableAccount(account)
                } else if self.authManager.isAutoDisabled(account) {
                    success = self.authManager.autoRestoreAccount(account)
                } else {
                    success = false
                }
            } else {
                success = self.authManager.disableAccount(account)
            }

            if success {
                self.authResultSuccess = true
                self.authResultMessage = enabled
                    ? "✓ Enabled \(account.displayName)"
                    : "✓ Disabled \(account.displayName)"
            } else {
                self.authResultSuccess = false
                self.authResultMessage = "Failed to \(enabled ? "enable" : "disable") account"
            }
            self.showingAuthResult = true

            if wasRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + Timing.serverRestartDelay) {
                    self.serverManager.start { _ in }
                }
            }
        }

        if wasRunning {
            serverManager.stop { action() }
        } else {
            action()
        }
    }

    private func disconnectAccount(_ account: AuthAccount) {
        let wasRunning = serverManager.isRunning
        
        // Stop server, delete file, restart
        let cleanup = {
            if self.authManager.deleteAccount(account) {
                self.authResultSuccess = true
                self.authResultMessage = "✓ Removed \(account.displayName) from \(account.type.displayName)"
            } else {
                self.authResultSuccess = false
                self.authResultMessage = "Failed to remove account"
            }
            self.showingAuthResult = true
            
            if wasRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + Timing.serverRestartDelay) {
                    self.serverManager.start { _ in }
                }
            }
        }
        
        if wasRunning {
            serverManager.stop { cleanup() }
        } else {
            cleanup()
        }
    }
    
    // MARK: - Models

    private func fetchModels() {
        guard let url = URL(string: "http://localhost:8317/v1/models") else { return }
        modelsLoading = true
        modelsError = nil

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
                let grouped = Dictionary(grouping: response.data) { $0.owned_by }
                    .mapValues { $0.sorted { $0.id < $1.id } }
                await MainActor.run {
                    availableModels = grouped
                    modelsLoading = false
                }
            } catch {
                await MainActor.run {
                    availableModels = [:]
                    modelsError = "Could not load models"
                    modelsLoading = false
                }
            }
        }
    }

    private func providerDisplayName(_ key: String) -> String {
        switch key {
        case "anthropic": return "Anthropic"
        case "openai": return "OpenAI"
        case "google": return "Google"
        case "alibaba", "qwen": return "Qwen"
        case "zhipu", "zai": return "Z.AI"
        default: return key.capitalized
        }
    }

    private func providerIcon(_ key: String) -> String {
        switch key {
        case "anthropic": return "a.circle.fill"
        case "openai": return "o.circle.fill"
        case "google": return "g.circle.fill"
        default: return "cpu"
        }
    }

    // MARK: - File Monitoring
    
    private func startMonitoringAuthDirectory() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        try? FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        
        let fileDescriptor = open(authDir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )
        
        source.setEventHandler { [self] in
            // Debounce rapid file changes to prevent UI flashing
            pendingRefresh?.cancel()
            let workItem = DispatchWorkItem {
                NSLog("[FileMonitor] Auth directory changed - refreshing status")
                authManager.checkAuthStatus()
            }
            pendingRefresh = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.refreshDebounce, execute: workItem)
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        fileMonitor = source
    }
    
    private func stopMonitoringAuthDirectory() {
        pendingRefresh?.cancel()
        fileMonitor?.cancel()
        fileMonitor = nil
    }
}
