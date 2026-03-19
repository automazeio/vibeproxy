import Foundation

enum ServiceType: String, CaseIterable {
    case claude
    case codex
    case copilot = "github-copilot"
    case gemini
    case qwen
    case antigravity
    case zai

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .copilot: return "GitHub Copilot"
        case .gemini: return "Gemini"
        case .qwen: return "Qwen"
        case .antigravity: return "Antigravity"
        case .zai: return "Z.AI GLM"
        }
    }
}

/// Represents a single authenticated account
struct AuthAccount: Identifiable, Equatable {
    let id: String  // filename
    let email: String?
    let login: String?  // for Copilot
    let type: ServiceType
    let expired: Date?
    let filePath: URL
    
    var isExpired: Bool {
        guard let expired = expired else { return false }
        return expired < Date()
    }
    
    var displayName: String {
        if let email = email, !email.isEmpty {
            return email
        }
        if let login = login, !login.isEmpty {
            return login
        }
        return id
    }
    
    static func == (lhs: AuthAccount, rhs: AuthAccount) -> Bool {
        lhs.id == rhs.id
    }
}

/// Tracks all accounts for a service type
struct ServiceAccounts {
    var type: ServiceType
    var accounts: [AuthAccount] = []
    
    var hasAccounts: Bool { !accounts.isEmpty }
    var activeCount: Int { accounts.filter { !$0.isExpired }.count }
    var expiredCount: Int { accounts.filter { $0.isExpired }.count }
}

class AuthManager: ObservableObject {
    @Published var serviceAccounts: [ServiceType: ServiceAccounts] = [:]
    /// Accounts manually disabled by the user (file moved to .disabled/)
    @Published var manuallyDisabledAccounts: [AuthAccount] = []
    /// Accounts auto-disabled due to 0% usage (file moved to .disabled/.auto/)
    @Published var autoDisabledAccounts: [AuthAccount] = []

    private static let dateFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return [withFractional, standard]
    }()

    static let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
    private static let disabledDir = authDir.appendingPathComponent(".disabled")
    private static let autoDisabledDir = disabledDir.appendingPathComponent(".auto")

    init() {
        for type in ServiceType.allCases {
            serviceAccounts[type] = ServiceAccounts(type: type)
        }
        ensureDisabledDirs()
    }

    func accounts(for type: ServiceType) -> [AuthAccount] {
        serviceAccounts[type]?.accounts ?? []
    }

    func hasAccounts(for type: ServiceType) -> Bool {
        serviceAccounts[type]?.hasAccounts ?? false
    }

    /// Check if an account is manually disabled
    func isManuallyDisabled(_ account: AuthAccount) -> Bool {
        manuallyDisabledAccounts.contains { $0.id == account.id }
    }

    /// Check if an account is auto-disabled (depleted)
    func isAutoDisabled(_ account: AuthAccount) -> Bool {
        autoDisabledAccounts.contains { $0.id == account.id }
    }

    /// Manually disable an account — moves file to .disabled/
    func disableAccount(_ account: AuthAccount) -> Bool {
        let dest = Self.disabledDir.appendingPathComponent(account.id)
        do {
            try FileManager.default.moveItem(at: account.filePath, to: dest)
            NSLog("[AuthStatus] Disabled account: %@ → .disabled/", account.displayName)
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to disable account %@: %@", account.displayName, error.localizedDescription)
            return false
        }
    }

    /// Re-enable a manually disabled account — moves file back
    func enableAccount(_ account: AuthAccount) -> Bool {
        let source = Self.disabledDir.appendingPathComponent(account.id)
        let dest = Self.authDir.appendingPathComponent(account.id)
        do {
            try FileManager.default.moveItem(at: source, to: dest)
            NSLog("[AuthStatus] Re-enabled account: %@ → active", account.displayName)
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to re-enable account %@: %@", account.displayName, error.localizedDescription)
            return false
        }
    }

    /// Auto-disable a depleted account (0% usage) — moves to .disabled/.auto/
    func autoDisableAccount(_ account: AuthAccount) -> Bool {
        // Don't auto-disable if already manually disabled
        guard !isManuallyDisabled(account) else { return false }
        let dest = Self.autoDisabledDir.appendingPathComponent(account.id)
        do {
            try FileManager.default.moveItem(at: account.filePath, to: dest)
            NSLog("[AuthStatus] Auto-disabled depleted account: %@", account.displayName)
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to auto-disable account %@: %@", account.displayName, error.localizedDescription)
            return false
        }
    }

    /// Restore an auto-disabled account when usage recovers
    func autoRestoreAccount(_ account: AuthAccount) -> Bool {
        let source = Self.autoDisabledDir.appendingPathComponent(account.id)
        let dest = Self.authDir.appendingPathComponent(account.id)
        do {
            try FileManager.default.moveItem(at: source, to: dest)
            NSLog("[AuthStatus] Auto-restored account: %@ (usage recovered)", account.displayName)
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to auto-restore account %@: %@", account.displayName, error.localizedDescription)
            return false
        }
    }

    func checkAuthStatus() {
        let authDir = Self.authDir

        var newAccounts: [ServiceType: [AuthAccount]] = [:]
        for type in ServiceType.allCases {
            newAccounts[type] = []
        }

        var newManuallyDisabled: [AuthAccount] = []
        var newAutoDisabled: [AuthAccount] = []

        do {
            // Scan active accounts
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            NSLog("[AuthStatus] Scanning %d files in auth directory", files.count)

            for file in files where file.pathExtension == "json" {
                guard let account = parseAccountFile(file) else { continue }
                newAccounts[account.type]?.append(account)
                NSLog("[AuthStatus] Found %@ auth: %@", account.type.displayName, account.displayName)
            }

            // Scan manually disabled accounts
            if let disabledFiles = try? FileManager.default.contentsOfDirectory(at: Self.disabledDir, includingPropertiesForKeys: nil) {
                for file in disabledFiles where file.pathExtension == "json" {
                    if let account = parseAccountFile(file) {
                        newManuallyDisabled.append(account)
                        NSLog("[AuthStatus] Found manually disabled: %@", account.displayName)
                    }
                }
            }

            // Scan auto-disabled accounts
            if let autoFiles = try? FileManager.default.contentsOfDirectory(at: Self.autoDisabledDir, includingPropertiesForKeys: nil) {
                for file in autoFiles where file.pathExtension == "json" {
                    if let account = parseAccountFile(file) {
                        newAutoDisabled.append(account)
                        NSLog("[AuthStatus] Found auto-disabled: %@", account.displayName)
                    }
                }
            }

            DispatchQueue.main.async {
                for type in ServiceType.allCases {
                    self.serviceAccounts[type] = ServiceAccounts(
                        type: type,
                        accounts: (newAccounts[type] ?? []).sorted { $0.id < $1.id }
                    )
                }
                self.manuallyDisabledAccounts = newManuallyDisabled.sorted { $0.id < $1.id }
                self.autoDisabledAccounts = newAutoDisabled.sorted { $0.id < $1.id }
            }
        } catch {
            NSLog("[AuthStatus] Error checking auth status: %@", error.localizedDescription)
            DispatchQueue.main.async {
                for type in ServiceType.allCases {
                    self.serviceAccounts[type] = ServiceAccounts(type: type)
                }
                self.manuallyDisabledAccounts = []
                self.autoDisabledAccounts = []
            }
        }
    }


    /// Delete a specific account's auth file
    func deleteAccount(_ account: AuthAccount) -> Bool {
        do {
            try FileManager.default.removeItem(at: account.filePath)
            NSLog("[AuthStatus] Deleted auth file: %@", account.filePath.path)
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to delete auth file: %@", error.localizedDescription)
            return false
        }
    }

    // MARK: - Private

    private func ensureDisabledDirs() {
        let fm = FileManager.default
        for dir in [Self.disabledDir, Self.autoDisabledDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    private func parseAccountFile(_ file: URL) -> AuthAccount? {
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              let serviceType = ServiceType(rawValue: type.lowercased()) else {
            return nil
        }

        let email = json["email"] as? String
        let login = json["login"] as? String
        var expiredDate: Date?

        if let expiredStr = json["expired"] as? String {
            for formatter in Self.dateFormatters {
                if let date = formatter.date(from: expiredStr) {
                    expiredDate = date
                    break
                }
            }
        }

        return AuthAccount(
            id: file.lastPathComponent,
            email: email,
            login: login,
            type: serviceType,
            expired: expiredDate,
            filePath: file
        )
    }
}
