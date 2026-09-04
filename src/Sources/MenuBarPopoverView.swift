import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var serverManager: ServerManager
    @ObservedObject var authManager: AuthManager
    @AppStorage("hideAccountEmailsInMenu") private var hideAccountEmails = false
    let proxyPort: UInt16
    let onToggleServer: () -> Void
    let onOpenSettings: () -> Void
    let onCopyServerURL: () -> Void
    let onOpenDashboard: () -> Void
    let onCheckForUpdates: () -> Void
    let onQuit: () -> Void

    private var quotaAccounts: [AuthAccount] {
        authManager.accounts(for: .claude) + authManager.accounts(for: .codex)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VibeProxy")
                        .font(.headline)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(serverManager.isRunning ? Color.green : Color.red)
                            .frame(width: 7, height: 7)
                        Text(serverManager.isRunning ? "Running on port \(String(proxyPort))" : "Server stopped")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(serverManager.isRunning ? "Stop Server" : "Start Server", action: onToggleServer)
                    .controlSize(.small)
            }
            .padding(14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    QuotaOverviewView(
                        accounts: quotaAccounts,
                        store: serverManager.quotaStore,
                        serverIsRunning: serverManager.isRunning,
                        hideAccountEmails: hideAccountEmails,
                        onToggleEmailPrivacy: { hideAccountEmails.toggle() },
                        onToggleAccount: toggleAccount
                    )
                }
                .padding(14)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: 440)

            Divider()

            VStack(spacing: 2) {
                MenuActionRow(title: "Open Settings", systemImage: "gearshape", action: onOpenSettings)
                    .keyboardShortcut("s", modifiers: .command)
                MenuActionRow(
                    title: "Copy Server URL",
                    systemImage: "doc.on.doc",
                    isEnabled: serverManager.isRunning,
                    action: onCopyServerURL
                )
                .keyboardShortcut("c", modifiers: .command)
                MenuActionRow(
                    title: "Open Dashboard",
                    systemImage: "gauge",
                    isEnabled: serverManager.isRunning,
                    action: onOpenDashboard
                )
                .keyboardShortcut("d", modifiers: .command)
                MenuActionRow(title: "Check for Updates", systemImage: "arrow.triangle.2.circlepath", action: onCheckForUpdates)
                    .keyboardShortcut("u", modifiers: .command)
                MenuActionRow(title: "Quit VibeProxy", systemImage: "power", action: onQuit)
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(8)
        }
        .frame(width: 480)
    }

    private func toggleAccount(_ account: AuthAccount) -> Bool {
        guard authManager.toggleAccountDisabled(account) else { return false }
        serverManager.refreshAuthBackedConfiguration()
        return true
    }
}

private struct MenuActionRow: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}
