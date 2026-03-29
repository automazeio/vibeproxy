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
    let isDisabled: Bool
    
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
    
    private static let dateFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return [withFractional, standard]
    }()
    
    init() {
        // Initialize empty accounts for all service types
        for type in ServiceType.allCases {
            serviceAccounts[type] = ServiceAccounts(type: type)
        }
    }
    
    func accounts(for type: ServiceType) -> [AuthAccount] {
        serviceAccounts[type]?.accounts ?? []
    }
    
    func hasAccounts(for type: ServiceType) -> Bool {
        serviceAccounts[type]?.hasAccounts ?? false
    }
    
    func checkAuthStatus() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        
        // Build new accounts dictionary
        var newAccounts: [ServiceType: [AuthAccount]] = [:]
        for type in ServiceType.allCases {
            newAccounts[type] = []
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            NSLog("[AuthStatus] Scanning %d files in auth directory", files.count)
            
            for file in files where file.pathExtension == "json" {
                NSLog("[AuthStatus] Checking file: %@", file.lastPathComponent)
                guard let data = try? Data(contentsOf: file),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String,
                      let serviceType = ServiceType(rawValue: type.lowercased()) else {
                    continue
                }
                
                NSLog("[AuthStatus] Found type '%@' in %@", type, file.lastPathComponent)
                
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
                
                let isDisabled = json["disabled"] as? Bool ?? false
                
                let account = AuthAccount(
                    id: file.lastPathComponent,
                    email: email,
                    login: login,
                    type: serviceType,
                    expired: expiredDate,
                    filePath: file,
                    isDisabled: isDisabled
                )
                
                newAccounts[serviceType]?.append(account)
                NSLog("[AuthStatus] Found %@ auth: %@", serviceType.displayName, account.displayName)
            }
            
            // Update on main thread
            DispatchQueue.main.async {
                for type in ServiceType.allCases {
                    self.serviceAccounts[type] = ServiceAccounts(
                        type: type,
                        accounts: newAccounts[type] ?? []
                    )
                }
            }
        } catch {
            NSLog("[AuthStatus] Error checking auth status: %@", error.localizedDescription)
            DispatchQueue.main.async {
                for type in ServiceType.allCases {
                    self.serviceAccounts[type] = ServiceAccounts(type: type)
                }
            }
        }
    }
    
    /// Toggle the disabled state of a specific account's auth file
    func toggleAccountDisabled(_ account: AuthAccount) -> Bool {
        do {
            let data = try Data(contentsOf: account.filePath)
            guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                NSLog("[AuthStatus] Failed to parse auth file as JSON: %@", account.filePath.path)
                return false
            }
            let currentlyDisabled = json["disabled"] as? Bool ?? false
            if !currentlyDisabled {
                let enabledCount = serviceAccounts[account.type]?.accounts.filter { !$0.isDisabled }.count ?? 0
                guard enabledCount > 1 else {
                    NSLog("[AuthStatus] Refusing to disable last enabled account for %@", account.type.rawValue)
                    return false
                }
            }
            json["disabled"] = !currentlyDisabled
            let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            try updatedData.write(to: account.filePath, options: .atomic)
            NSLog("[AuthStatus] Toggled disabled=%d for: %@", !currentlyDisabled, account.filePath.path)
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to toggle disabled state: %@", error.localizedDescription)
            return false
        }
    }
    
    /// Delete a specific account's auth file
    func deleteAccount(_ account: AuthAccount) -> Bool {
        do {
            try FileManager.default.removeItem(at: account.filePath)
            NSLog("[AuthStatus] Deleted auth file: %@", account.filePath.path)
            // Refresh status
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to delete auth file: %@", error.localizedDescription)
            return false
        }
    }
}
