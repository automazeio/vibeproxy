import SwiftUI

struct QuotaOverviewView: View {
    let accounts: [AuthAccount]
    @ObservedObject var store: QuotaStore
    let serverIsRunning: Bool
    let hideAccountEmails: Bool
    let onToggleEmailPrivacy: () -> Void
    let onToggleAccount: (AuthAccount) -> Bool

    @State private var resetAlert: ResetAlert?
    @State private var resetAccountID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Usage limits")
                        .font(.headline)

                    if !serverIsRunning {
                        Text("Start the server to refresh quotas")
                            .foregroundColor(.secondary)
                    } else if let lastUpdated = store.lastUpdated {
                        Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Provider-reported remaining usage")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)

                Spacer()

                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(action: onToggleEmailPrivacy) {
                    Image(systemName: hideAccountEmails ? "eye.slash" : "eye")
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(hideAccountEmails ? "Show account emails" : "Blur account emails")
                .accessibilityLabel(hideAccountEmails ? "Show account emails" : "Blur account emails")

                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!serverIsRunning || store.isRefreshing || accounts.isEmpty)
                .help("Refresh quotas")
            }

            if accounts.isEmpty {
                Text("Add an Anthropic or OpenAI account to see its usage limits.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(QuotaProvider.allCases, id: \QuotaProvider.self) { (provider: QuotaProvider) in
                    let providerAccounts = accounts
                        .filter { QuotaProvider(serviceType: $0.type) == provider }
                        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                    if !providerAccounts.isEmpty {
                        QuotaProviderGroupView(
                            provider: provider,
                            accounts: providerAccounts,
                            states: store.states,
                            canUseResets: serverIsRunning,
                            resetAccountID: resetAccountID,
                            hideAccountEmails: hideAccountEmails,
                            onReset: prepareReset,
                            onToggleAccount: toggleAccount
                        )
                    }
                }
            }
        }
        .alert(item: $resetAlert) { alert in
            switch alert {
            case .confirmation(let prompt):
                return Alert(
                    title: Text("Use Full reset?"),
                    message: Text(confirmationMessage(for: prompt)),
                    primaryButton: .default(Text("Use Reset")) {
                        consumeReset(prompt)
                    },
                    secondaryButton: .cancel()
                )
            case .message(let title, let message):
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func refresh() {
        store.refresh(accounts: accounts, force: true)
    }

    private func prepareReset(_ account: AuthAccount, displayName: String) {
        guard resetAccountID == nil else { return }
        resetAccountID = account.id
        Task { @MainActor in
            defer { resetAccountID = nil }
            do {
                let credit = try await store.resetCredit(for: account)
                resetAlert = .confirmation(ResetPrompt(
                    account: account,
                    accountDisplayName: displayName,
                    credit: credit
                ))
            } catch {
                resetAlert = .message(
                    title: "Reset unavailable",
                    message: resetFailureMessage(error)
                )
            }
        }
    }

    private func consumeReset(_ prompt: ResetPrompt) {
        guard resetAccountID == nil else { return }
        resetAccountID = prompt.account.id
        Task { @MainActor in
            defer { resetAccountID = nil }
            do {
                let outcome = try await store.consumeResetCredit(prompt.credit, for: prompt.account)
                resetAlert = outcomeAlert(outcome)
            } catch {
                resetAlert = .message(
                    title: "Reset failed",
                    message: resetFailureMessage(error)
                )
            }
        }
    }

    private func confirmationMessage(for prompt: ResetPrompt) -> String {
        var message = "Use 1 \(prompt.credit.title) for \(prompt.accountDisplayName)?"
        if let expiresAt = prompt.credit.expiresAt {
            message += " It expires \(expiresAt.formatted(date: .abbreviated, time: .shortened))."
        }
        return message
    }

    private func outcomeAlert(_ outcome: CodexResetOutcome) -> ResetAlert {
        switch outcome {
        case .reset:
            return .message(title: "Usage reset", message: "OpenAI usage limits are refreshing now.")
        case .nothingToReset:
            return .message(title: "Nothing to reset", message: "This account has no active limit to reset.")
        case .noCredit:
            return .message(title: "No reset available", message: "This account has no banked reset available.")
        case .alreadyRedeemed:
            return .message(title: "Reset already used", message: "This reset was already redeemed.")
        }
    }

    private func resetFailureMessage(_ error: Error) -> String {
        guard let failure = error as? QuotaFailure else {
            return "Try again after refreshing usage."
        }
        switch failure {
        case .accountUnavailable:
            return "No usable reset is available for this account."
        case .providerAuthenticationFailed:
            return "Sign in to this OpenAI account again."
        case .rateLimited:
            return "OpenAI is rate limiting requests. Try again later."
        default:
            return "Try again after refreshing usage."
        }
    }

    private func toggleAccount(_ account: AuthAccount, displayName: String) {
        guard onToggleAccount(account) else {
            resetAlert = .message(
                title: "Account unchanged",
                message: "Could not update \(displayName). Try again."
            )
            return
        }
    }
}

private struct QuotaProviderGroupView: View {
    let provider: QuotaProvider
    let accounts: [AuthAccount]
    let states: [String: AccountQuotaState]
    let canUseResets: Bool
    let resetAccountID: String?
    let hideAccountEmails: Bool
    let onReset: (AuthAccount, String) -> Void
    let onToggleAccount: (AuthAccount, String) -> Void

    @State private var isExpanded: Bool

    init(
        provider: QuotaProvider,
        accounts: [AuthAccount],
        states: [String: AccountQuotaState],
        canUseResets: Bool,
        resetAccountID: String?,
        hideAccountEmails: Bool,
        onReset: @escaping (AuthAccount, String) -> Void,
        onToggleAccount: @escaping (AuthAccount, String) -> Void
    ) {
        self.provider = provider
        self.accounts = accounts
        self.states = states
        self.canUseResets = canUseResets
        self.resetAccountID = resetAccountID
        self.hideAccountEmails = hideAccountEmails
        self.onReset = onReset
        self.onToggleAccount = onToggleAccount
        _isExpanded = State(initialValue: provider == .anthropic)
    }

    private var exhaustedCount: Int {
        accounts.filter { !$0.isDisabled && states[$0.id]?.snapshot?.isExhausted == true }.count
    }

    private var collapsedSummary: String? {
        let activeAccounts = accounts.filter { !$0.isDisabled }
        let now = Date()
        let nextReset = activeAccounts
            .compactMap { states[$0.id]?.snapshot }
            .flatMap(\.windows)
            .compactMap(\.resetsAt)
            .filter { $0 > now }
            .min()
        if let nextReset {
            return "resets in \(QuotaTimeFormatter.compact(until: nextReset, now: now))"
        }
        return activeAccounts.contains { states[$0.id]?.failure != nil } ? "quota unavailable" : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 10)

                    providerIcon

                    Text(provider.displayName)
                        .font(.system(size: 13, weight: .semibold))

                    Text("\(accounts.count)")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))

                    if exhaustedCount > 0 {
                        Text("\(exhaustedCount)")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.red)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.red.opacity(0.1)))
                            .accessibilityLabel("\(exhaustedCount) exhausted accounts")
                            .help("\(exhaustedCount) exhausted accounts")
                    }

                    Spacer()

                    if !isExpanded, let collapsedSummary {
                        Text(collapsedSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)

            if isExpanded {
                Divider()

                QuotaColumnHeader()

                let enabledCount = accounts.filter { !$0.isDisabled }.count
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    let displayName = account.displayName
                    let privateDisplayName = hideAccountEmails ? "this account" : displayName
                    if index > 0 {
                        Divider().padding(.leading, QuotaGridLayout.accountWidth + 12)
                    }
                    QuotaAccountGridRow(
                        account: account,
                        provider: provider,
                        state: states[account.id],
                        canUseReset: canUseResets,
                        canToggleAccount: account.isDisabled || enabledCount > 1,
                        isResetting: resetAccountID == account.id,
                        displayName: displayName,
                        hideAccountEmail: hideAccountEmails,
                        onReset: { onReset(account, privateDisplayName) },
                        onToggleAccount: { onToggleAccount(account, privateDisplayName) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var providerIcon: some View {
        if let image = IconCatalog.shared.image(
            named: provider.iconName,
            resizedTo: NSSize(width: 16, height: 16),
            template: true
        ) {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .frame(width: 16, height: 16)
        }
    }
}

private struct QuotaColumnHeader: View {
    var body: some View {
        HStack(spacing: QuotaGridLayout.spacing) {
            Text("ACCOUNT")
                .frame(width: QuotaGridLayout.accountWidth, alignment: .leading)
            Text("5-HOUR")
                .frame(width: QuotaGridLayout.cellWidth)
            Text("WEEKLY")
                .frame(width: QuotaGridLayout.cellWidth)
            Text("FABLE")
                .frame(width: QuotaGridLayout.cellWidth)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 3)
    }
}

private struct QuotaAccountGridRow: View {
    let account: AuthAccount
    let provider: QuotaProvider
    let state: AccountQuotaState?
    let canUseReset: Bool
    let canToggleAccount: Bool
    let isResetting: Bool
    let displayName: String
    let hideAccountEmail: Bool
    let onReset: () -> Void
    let onToggleAccount: () -> Void

    var body: some View {
        HStack(spacing: QuotaGridLayout.spacing) {
            HStack(spacing: 5) {
                Text(displayName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(account.isDisabled ? .secondary : .primary)
                    .strikethrough(account.isDisabled)
                    .blur(radius: hideAccountEmail ? 4.5 : 0)
                    .accessibilityLabel(hideAccountEmail ? "Hidden account email" : displayName)

                Spacer(minLength: 1)

                if provider == .openAI,
                   let availability = state?.snapshot?.resetCredits,
                   availability.availableCount > 0 {
                    CodexResetBadge(
                        availability: availability,
                        isEnabled: canUseReset,
                        isLoading: isResetting,
                        action: onReset
                    )
                }

                if let failure = state?.failure {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                        .help(failure.displayText)
                }

                AccountEnabledToggle(
                    isEnabled: !account.isDisabled,
                    canToggle: canToggleAccount,
                    action: onToggleAccount
                )
            }
            .frame(width: QuotaGridLayout.accountWidth, alignment: .leading)

            QuotaCell(window: state?.snapshot?.window(.fiveHour))
                .opacity(account.isDisabled ? 0.45 : 1)
            QuotaCell(window: state?.snapshot?.window(.weekly))
                .opacity(account.isDisabled ? 0.45 : 1)
            QuotaCell(window: provider == .anthropic ? state?.snapshot?.window(.fable) : nil)
                .opacity(account.isDisabled ? 0.45 : 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct AccountEnabledToggle: View {
    let isEnabled: Bool
    let canToggle: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "power")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(isEnabled ? .secondary : Color.secondary.opacity(0.45))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.secondary.opacity(isEnabled ? 0.1 : 0.05))
                )
        }
        .buttonStyle(.plain)
        .frame(minWidth: 24, minHeight: 20)
        .contentShape(Rectangle())
        .disabled(!canToggle)
        .help(helpText)
        .accessibilityLabel(isEnabled ? "Disable account" : "Enable account")
    }

    private var helpText: String {
        if !canToggle {
            return "At least one account must remain enabled"
        }
        return isEnabled ? "Disable account" : "Enable account"
    }
}

private struct CodexResetBadge: View {
    let availability: CodexResetAvailability
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if availability.canReset && isEnabled {
                Button(action: action) {
                    label
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .help("Use a banked Full reset")
            } else {
                label
                    .foregroundColor(.secondary)
                    .help(helpText)
            }
        }
    }

    private var label: some View {
        HStack(spacing: 2) {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 8, weight: .semibold))
            }
            Text("\(availability.availableCount)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .foregroundColor(
            availability.canReset && isEnabled
                ? .secondary
                : Color.secondary.opacity(0.5)
        )
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.secondary.opacity(0.08)))
    }

    private var helpText: String {
        if !isEnabled {
            return "Start the server to use a banked reset"
        }
        return "\(availability.availableCount) banked reset available; usable after a limit is reached"
    }
}

private struct QuotaCell: View {
    let window: QuotaWindow?

    var body: some View {
        VStack(spacing: 1) {
            if let window {
                Text("\(Int(window.remainingPercent.rounded()))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(QuotaColor.color(for: window.remainingPercent))

                Text(resetText(window.resetsAt))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(height: 24)
            }
        }
        .frame(width: QuotaGridLayout.cellWidth)
    }

    private func resetText(_ date: Date?) -> String {
        guard let date else { return "no reset" }
        return QuotaTimeFormatter.compact(until: date)
    }
}

private enum QuotaGridLayout {
    static let accountWidth: CGFloat = 145
    static let cellWidth: CGFloat = 68
    static let spacing: CGFloat = 6
}

private enum QuotaColor {
    static func color(for remainingPercent: Double) -> Color {
        switch remainingPercent {
        case ...0: return .red
        case ..<20: return .orange
        default: return .primary
        }
    }
}

private enum QuotaTimeFormatter {
    static func compact(until date: Date, now: Date = Date()) -> String {
        let interval = max(0, date.timeIntervalSince(now))
        if interval < 60 { return "now" }
        if interval < 3_600 { return "\(Int(ceil(interval / 60)))m" }
        if interval < 86_400 { return "\(Int(ceil(interval / 3_600)))h" }
        return "\(Int(ceil(interval / 86_400)))d"
    }
}

private struct ResetPrompt {
    let account: AuthAccount
    let accountDisplayName: String
    let credit: CodexResetCredit
}

private enum ResetAlert: Identifiable {
    case confirmation(ResetPrompt)
    case message(title: String, message: String)

    var id: String {
        switch self {
        case .confirmation(let prompt): return "confirm-\(prompt.credit.id)"
        case .message(let title, let message): return "message-\(title)-\(message)"
        }
    }
}
