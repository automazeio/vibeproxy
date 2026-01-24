import SwiftUI

//  Quota Progress Bar

struct QuotaProgressBar: View {
    let percent: Double?
    var highThreshold: Double = 60
    var mediumThreshold: Double = 20

    private var color: Color {
        guard let percent = percent else { return .gray }
        if percent >= highThreshold {
            return .green
        } else if percent >= mediumThreshold {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))

                if let percent = percent {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(1, max(0, percent / 100)))
                }
            }
        }
        .frame(height: 6)
    }
}

//  Quota Row (single model/window)

struct QuotaItemRow: View {
    let label: String
    let percent: Double?
    let resetTime: String
    var tooltip: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
                    .help(tooltip ?? label)

                Spacer()

                Text(percent != nil ? "\(Int(percent!))%" : "--")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(resetTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            QuotaProgressBar(percent: percent)
        }
    }
}

//  Account Quota Row (collapsible)

struct AccountQuotaRow: View {
    let account: AuthAccount
    let iconName: String
    @Binding var isExpanded: Bool

    @State private var isLoading = false
    @State private var error: String?

    // Quota data
    @State private var antigravityGroups: [AntigravityQuotaGroup] = []
    @State private var geminiCliBuckets: [GeminiCliQuotaBucket] = []
    @State private var codexQuota: CodexQuota?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header - clickable to expand/collapse
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 10)

                Circle()
                    .fill(account.isExpired ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)

                Text(account.displayName)
                    .font(.caption)
                    .foregroundColor(account.isExpired ? .orange : .primary)

                if account.isExpired {
                    Text("(expired)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }

                // Refresh button
                Button(action: loadQuota) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Refresh quota")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
                // Always refresh when expanding
                if isExpanded && !isLoading {
                    loadQuota()
                }
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let error = error {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.leading, 16)
                    } else if isLoading && !hasData {
                        Text("Loading...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                    } else if !hasData {
                        Text("Not loaded. Click Refresh Button.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                    } else {
                        quotaContent
                            .padding(.leading, 16)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 2)
    }

    private var hasData: Bool {
        !antigravityGroups.isEmpty || !geminiCliBuckets.isEmpty || codexQuota != nil
    }

    @ViewBuilder
    private var quotaContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Antigravity
            ForEach(antigravityGroups) { group in
                QuotaItemRow(
                    label: group.label,
                    percent: group.remainingFraction * 100,
                    resetTime: QuotaService.shared.formatResetTime(group.resetTime),
                    tooltip: group.models.joined(separator: ", ")
                )
            }

            // Gemini CLI
            ForEach(geminiCliBuckets) { bucket in
                QuotaItemRow(
                    label: bucket.label,
                    percent: bucket.remainingFraction.map { $0 * 100 },
                    resetTime: QuotaService.shared.formatResetTime(bucket.resetTime),
                    tooltip: bucket.modelIds.joined(separator: ", ")
                )
            }

            // Codex
            if let quota = codexQuota {
                if let planType = quota.planType {
                    HStack(spacing: 4) {
                        Text("Plan:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatPlanType(planType))
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }

                if quota.planType?.lowercased() == "free" {
                    Text("Free plan - limited access")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    ForEach(quota.windows) { window in
                        QuotaItemRow(
                            label: window.label,
                            percent: window.remainingPercent,
                            resetTime: QuotaService.shared.formatResetTime(window.resetTime)
                        )
                    }
                }
            }
        }
    }

    private func formatPlanType(_ type: String) -> String {
        switch type.lowercased() {
        case "plus": return "Plus"
        case "team": return "Team"
        case "free": return "Free"
        default: return type
        }
    }

    private func loadQuota() {
        guard !account.isExpired else {
            error = "Token expired"
            return
        }

        isLoading = true
        error = nil

        // Clear cache to get fresh auth files
        QuotaService.shared.clearCache()

        Task {
            do {
                switch account.type {
                case .antigravity:
                    let groups = try await QuotaService.shared.fetchAntigravityQuota(account: account)
                    await MainActor.run {
                        antigravityGroups = groups
                        isLoading = false
                    }

                case .gemini:
                    let buckets = try await QuotaService.shared.fetchGeminiCliQuota(account: account)
                    await MainActor.run {
                        geminiCliBuckets = buckets
                        isLoading = false
                    }

                case .codex:
                    let quota = try await QuotaService.shared.fetchCodexQuota(account: account)
                    await MainActor.run {
                        codexQuota = quota
                        isLoading = false
                    }

                default:
                    await MainActor.run {
                        error = "Quota not supported"
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

//  Service Quota Section (collapsible, contains accounts)

struct ServiceQuotaSection: View {
    let serviceType: ServiceType
    let iconName: String
    let accounts: [AuthAccount]
    @Binding var isExpanded: Bool
    @State private var expandedAccounts: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Service header
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 12)

                if let nsImage = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 16, height: 16), template: true) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 16, height: 16)
                }

                Text(serviceType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("(\(accounts.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }

            // Accounts list
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                        if index > 0 {
                            Divider()
                                .padding(.vertical, 2)
                        }
                        AccountQuotaRow(
                            account: account,
                            iconName: iconName,
                            isExpanded: Binding(
                                get: { expandedAccounts.contains(account.id) },
                                set: { newValue in
                                    if newValue {
                                        expandedAccounts.insert(account.id)
                                    } else {
                                        expandedAccounts.remove(account.id)
                                    }
                                }
                            )
                        )
                    }
                }
                .padding(.leading, 18)
            }
        }
        .padding(.vertical, 4)
    }
}

//  Main Quota Section (for SettingsView)

struct QuotaSection: View {
    @ObservedObject var authManager: AuthManager

    // Track which services are expanded (default: collapsed)
    @State private var expandedServices: Set<ServiceType> = []

    private var quotaServices: [(ServiceType, String, [AuthAccount])] {
        [
            (.antigravity, "icon-antigravity.png", authManager.accounts(for: .antigravity)),
            (.gemini, "icon-gemini.png", authManager.accounts(for: .gemini)),
            (.codex, "icon-codex.png", authManager.accounts(for: .codex))
        ].filter { !$0.2.isEmpty }
    }

    var body: some View {
        if quotaServices.isEmpty {
            Text("Connect to a service to view quota")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(quotaServices.enumerated()), id: \.element.0) { index, service in
                    let (serviceType, iconName, accounts) = service
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    ServiceQuotaSection(
                        serviceType: serviceType,
                        iconName: iconName,
                        accounts: accounts,
                        isExpanded: Binding(
                            get: { expandedServices.contains(serviceType) },
                            set: { newValue in
                                if newValue {
                                    expandedServices.insert(serviceType)
                                } else {
                                    expandedServices.remove(serviceType)
                                }
                            }
                        )
                    )
                }
            }
        }
    }
}

//  Preview

#Preview {
    QuotaSection(authManager: AuthManager())
        .frame(width: 400)
        .padding()
}
