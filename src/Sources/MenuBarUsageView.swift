import Cocoa

/// Builds and updates plain NSMenuItems for provider usage in the menu bar.
/// Items are non-interactive, styled like "Server: Running (port 8317)".
@MainActor
final class MenuBarUsageItemsController {
    private let authManager: AuthManager
    private let codexUsageManager: CodexUsageManager
    private let claudeUsageManager: ClaudeUsageManager
    private let thinkingProxy: ThinkingProxy
    private var refreshTimer: Timer?
    /// Callback to trigger auto-disable check in AppDelegate
    var onRefresh: (() -> Void)?

    private(set) var menuItems: [NSMenuItem] = []
    private weak var menu: NSMenu?
    private let insertionIndex: Int

    init(
        menu: NSMenu,
        insertionIndex: Int,
        authManager: AuthManager,
        codexUsageManager: CodexUsageManager,
        claudeUsageManager: ClaudeUsageManager,
        thinkingProxy: ThinkingProxy
    ) {
        self.menu = menu
        self.insertionIndex = insertionIndex
        self.authManager = authManager
        self.codexUsageManager = codexUsageManager
        self.claudeUsageManager = claudeUsageManager
        self.thinkingProxy = thinkingProxy

        // Refresh every 3s — cheap (just string updates) and always works
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildItems()
                self?.onRefresh?()
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func rebuildItems() {
        guard let menu = menu else { return }

        // Remove old items
        for item in menuItems { menu.removeItem(item) }
        menuItems.removeAll()

        var idx = insertionIndex

        // Claude accounts — kick off polling if accounts exist but no usage data yet
        let claudeAccounts = authManager.accounts(for: .claude).filter { !$0.isExpired }
        if !claudeAccounts.isEmpty && claudeUsageManager.usageByAccount.isEmpty {
            claudeUsageManager.startPolling(accounts: claudeAccounts)
        }
        let providerCounts = thinkingProxy.providerRequestCounts()

        let claudeDisabled = disabledAccounts(for: .claude)
        if !claudeAccounts.isEmpty || !claudeDisabled.isEmpty {
            let claudeTotal = providerCounts["claude"] ?? 0
            let claudePerAccount = perAccountCounts(totalRequests: claudeTotal, accountCount: claudeAccounts.count)
            let header = makeSectionHeader("Claude")
            menu.insertItem(header, at: idx); menuItems.append(header); idx += 1
            for (i, account) in claudeAccounts.enumerated() {
                let usage = claudeUsageManager.usage(for: account.id)
                let reqCount = claudeAccounts.count > 1 ? claudePerAccount[i] : nil
                let item = makeDisabledItem(formatAccountLine(email: account.displayName, usage: usage, requestCount: reqCount))
                menu.insertItem(item, at: idx); menuItems.append(item); idx += 1
            }
            // Show disabled/depleted accounts dimmed
            for (account, reason) in claudeDisabled {
                let item = makeDimmedItem("\(account.displayName)  (\(reason))")
                menu.insertItem(item, at: idx); menuItems.append(item); idx += 1
            }
            appendRotationIndicator(accounts: claudeAccounts, requestCount: claudeTotal, menu: menu, idx: &idx)
        }

        // Codex accounts — kick off polling if accounts exist but no usage data yet
        let codexAccounts = authManager.accounts(for: .codex).filter { !$0.isExpired }
        if !codexAccounts.isEmpty && codexUsageManager.usageByAccount.isEmpty {
            codexUsageManager.startPolling(accounts: codexAccounts)
        }
        let codexDisabled = disabledAccounts(for: .codex)
        if !codexAccounts.isEmpty || !codexDisabled.isEmpty {
            let codexTotal = providerCounts["codex"] ?? 0
            let codexPerAccount = perAccountCounts(totalRequests: codexTotal, accountCount: codexAccounts.count)
            let header = makeSectionHeader("Codex")
            menu.insertItem(header, at: idx); menuItems.append(header); idx += 1
            for (i, account) in codexAccounts.enumerated() {
                let usage = codexUsageManager.usage(for: account.id)
                let reqCount = codexAccounts.count > 1 ? codexPerAccount[i] : nil
                let item = makeDisabledItem(formatAccountLine(email: account.displayName, usage: usage, requestCount: reqCount))
                menu.insertItem(item, at: idx); menuItems.append(item); idx += 1
            }
            for (account, reason) in codexDisabled {
                let item = makeDimmedItem("\(account.displayName)  (\(reason))")
                menu.insertItem(item, at: idx); menuItems.append(item); idx += 1
            }
            appendRotationIndicator(accounts: codexAccounts, requestCount: codexTotal, menu: menu, idx: &idx)
        }

        // Separator after usage items (only if we added any)
        if !menuItems.isEmpty {
            let sep = NSMenuItem.separator()
            menu.insertItem(sep, at: idx)
            menuItems.append(sep)
        }
    }

    /// Get disabled accounts for a provider with their reason
    private func disabledAccounts(for type: ServiceType) -> [(AuthAccount, String)] {
        var result: [(AuthAccount, String)] = []
        for account in authManager.manuallyDisabledAccounts where account.type == type {
            result.append((account, "disabled"))
        }
        for account in authManager.autoDisabledAccounts where account.type == type {
            result.append((account, "no credits"))
        }
        return result.sorted { $0.0.id < $1.0.id }
    }

    private func formatAccountLine(email: String, usage: ProviderUsageData?, requestCount: Int?) -> String {
        var parts: [String] = []

        if let usage = usage {
            switch usage.status {
            case .loading:
                parts.append("⏳")
            case .invalidCredentials:
                parts.append("⚠️ expired")
            case .error:
                parts.append("⚠️ error")
            case .loaded:
                if let remaining = usage.primaryRemainingPercent {
                    if let reset = usage.primaryResetFormatted {
                        parts.append("\(remaining)%, \(reset)")
                    } else {
                        parts.append("\(remaining)%")
                    }
                }
            }
        }

        if let count = requestCount {
            parts.append("\(count) req")
        }

        if parts.isEmpty { return email }
        return "\(email)  (\(parts.joined(separator: ", ")))"
    }

    /// Compute estimated per-account request counts from round-robin total.
    private func perAccountCounts(totalRequests: Int, accountCount: Int) -> [Int] {
        guard accountCount > 0 else { return [] }
        let base = totalRequests / accountCount
        let remainder = totalRequests % accountCount
        return (0..<accountCount).map { i in base + (i < remainder ? 1 : 0) }
    }

    private func makeSectionHeader(_ providerName: String) -> NSMenuItem {
        let item = NSMenuItem(title: providerName, action: nil, keyEquivalent: "")
        item.isEnabled = false
        // Use labelColor — disabled items get dimmed by macOS; secondaryLabelColor becomes invisible
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        item.attributedTitle = NSAttributedString(string: providerName.uppercased(), attributes: attrs)
        return item
    }

    private func appendRotationIndicator(accounts: [AuthAccount], requestCount: Int, menu: NSMenu, idx: inout Int) {
        guard accounts.count > 1 else { return }
        let count = accounts.count
        if requestCount > 0 {
            let lastIdx = (requestCount - 1) % count
            let nextIdx = requestCount % count
            let text = "  \(accounts[lastIdx].displayName) \u{25B8} \(accounts[nextIdx].displayName)"
            let item = makeDisabledItem(text)
            menu.insertItem(item, at: idx); menuItems.append(item); idx += 1
        } else {
            let item = makeDisabledItem("  next \u{25B8} \(accounts[0].displayName)")
            menu.insertItem(item, at: idx); menuItems.append(item); idx += 1
        }
    }

    private func makeDisabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func makeDimmedItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        item.attributedTitle = NSAttributedString(string: "  \(title)", attributes: attrs)
        return item
    }
}
