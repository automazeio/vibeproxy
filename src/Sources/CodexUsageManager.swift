import Foundation

// MARK: - API Response Models (dual decode: nested object OR array)

struct CodexUsageResponse: Decodable {
    let primaryUsedPercent: Double?
    let primaryRemainingSeconds: Int?
    let secondaryUsedPercent: Double?
    let secondaryRemainingSeconds: Int?
    let creditBalance: Double?
    let planType: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RootKeys.self)
        planType = try? container.decode(String.self, forKey: .planType)

        // Credits — balance can be String "0" or Double 0
        let creditsContainer = try? container.nestedContainer(keyedBy: CreditsKeys.self, forKey: .credits)
        if let balanceStr = try? creditsContainer?.decode(String.self, forKey: .balance) {
            creditBalance = Double(balanceStr)
        } else {
            creditBalance = try? creditsContainer?.decode(Double.self, forKey: .balance)
        }

        // Try nested object first: { "rate_limit": { "primary_window": { ... } } }
        if let rlContainer = try? container.nestedContainer(keyedBy: RateLimitKeys.self, forKey: .rateLimit) {
            let primary = try? rlContainer.nestedContainer(keyedBy: WindowKeys.self, forKey: .primaryWindow)
            primaryUsedPercent = try? primary?.decode(Double.self, forKey: .usedPercent)
            primaryRemainingSeconds = try? primary?.decode(Int.self, forKey: .resetAfterSeconds)
            let secondary = try? rlContainer.nestedContainer(keyedBy: WindowKeys.self, forKey: .secondaryWindow)
            secondaryUsedPercent = try? secondary?.decode(Double.self, forKey: .usedPercent)
            secondaryRemainingSeconds = try? secondary?.decode(Int.self, forKey: .resetAfterSeconds)
        }
        // Fallback: array format { "rate_limits": [ { "window_type": "primary", ... } ] }
        else if let limits = try? container.decode([RateLimitEntry].self, forKey: .rateLimits) {
            let primary = limits.first { $0.windowType == "primary" }
            primaryUsedPercent = primary?.usedPercent
            primaryRemainingSeconds = primary?.resetAfterSeconds
            let secondary = limits.first { $0.windowType == "secondary" }
            secondaryUsedPercent = secondary?.usedPercent
            secondaryRemainingSeconds = secondary?.resetAfterSeconds
        } else {
            primaryUsedPercent = nil
            primaryRemainingSeconds = nil
            secondaryUsedPercent = nil
            secondaryRemainingSeconds = nil
        }
    }

    private enum RootKeys: String, CodingKey {
        case rateLimit = "rate_limit"
        case rateLimits = "rate_limits"
        case credits
        case planType = "plan_type"
    }
    private enum RateLimitKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
    private enum WindowKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAfterSeconds = "reset_after_seconds"
    }
    private enum CreditsKeys: String, CodingKey {
        case balance
    }
    private struct RateLimitEntry: Decodable {
        let windowType: String?
        let usedPercent: Double?
        let resetAfterSeconds: Int?
        enum CodingKeys: String, CodingKey {
            case windowType = "window_type"
            case usedPercent = "used_percent"
            case resetAfterSeconds = "reset_after_seconds"
        }
    }
}

// MARK: - UI-Facing Usage Data

struct ProviderUsageData {
    enum Status {
        case loading
        case loaded
        case error(String)
        case invalidCredentials
    }

    let status: Status
    let primaryUsedPercent: Double?
    let primaryResetSeconds: Int?
    let secondaryUsedPercent: Double?
    let secondaryResetSeconds: Int?
    let creditBalance: Double?
    let planType: String?
    let lastUpdated: Date?

    var primaryRemainingPercent: Int? {
        guard let used = primaryUsedPercent else { return nil }
        return max(0, Int(100 - used))
    }

    var secondaryRemainingPercent: Int? {
        guard let used = secondaryUsedPercent else { return nil }
        return max(0, Int(100 - used))
    }

    var primaryResetFormatted: String? {
        formatSeconds(primaryResetSeconds)
    }

    var secondaryResetFormatted: String? {
        formatSeconds(secondaryResetSeconds)
    }

    private func formatSeconds(_ seconds: Int?) -> String? {
        guard let s = seconds, s > 0 else { return nil }
        let h = s / 3600
        let m = (s % 3600) / 60
        if h >= 24 { return "\(h / 24)d \(h % 24)h" }
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    static let loading = ProviderUsageData(
        status: .loading,
        primaryUsedPercent: nil, primaryResetSeconds: nil,
        secondaryUsedPercent: nil, secondaryResetSeconds: nil,
        creditBalance: nil, planType: nil, lastUpdated: nil
    )
}

// MARK: - Manager

@MainActor
final class CodexUsageManager: ObservableObject {
    @Published private(set) var usageByAccount: [String: ProviderUsageData] = [:]

    private var pollTimer: Timer?
    private let session: URLSession
    private static let pollInterval: TimeInterval = 300 // 5 min
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    func startPolling(accounts: [AuthAccount]) {
        stopPolling()
        let active = accounts.filter { $0.type == .codex && !$0.isExpired }
        guard !active.isEmpty else {
            usageByAccount = [:]
            return
        }
        for a in active { usageByAccount[a.id] = .loading }
        fetchAll(active)
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.fetchAll(active) }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refreshNow(accounts: [AuthAccount]) {
        let active = accounts.filter { $0.type == .codex && !$0.isExpired }
        fetchAll(active)
    }

    func usage(for accountId: String) -> ProviderUsageData? {
        usageByAccount[accountId]
    }

    // MARK: - Private

    private func fetchAll(_ accounts: [AuthAccount]) {
        for account in accounts {
            Task { await fetchUsage(for: account) }
        }
    }

    private func fetchUsage(for account: AuthAccount) async {
        guard let creds = readCredentials(from: account.filePath) else {
            usageByAccount[account.id] = ProviderUsageData(
                status: .error("No credentials"), primaryUsedPercent: nil, primaryResetSeconds: nil,
                secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                creditBalance: nil, planType: nil, lastUpdated: Date()
            )
            return
        }

        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountId = creds.accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        do {
            let (data, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1

            if code == 200 {
                let parsed = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
                usageByAccount[account.id] = ProviderUsageData(
                    status: .loaded,
                    primaryUsedPercent: parsed.primaryUsedPercent,
                    primaryResetSeconds: parsed.primaryRemainingSeconds,
                    secondaryUsedPercent: parsed.secondaryUsedPercent,
                    secondaryResetSeconds: parsed.secondaryRemainingSeconds,
                    creditBalance: parsed.creditBalance,
                    planType: parsed.planType,
                    lastUpdated: Date()
                )
            } else if code == 401 || code == 403 {
                usageByAccount[account.id] = ProviderUsageData(
                    status: .invalidCredentials, primaryUsedPercent: nil, primaryResetSeconds: nil,
                    secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                    creditBalance: nil, planType: nil, lastUpdated: Date()
                )
            } else {
                NSLog("[CodexUsage] HTTP %d for %@", code, account.displayName)
                usageByAccount[account.id] = ProviderUsageData(
                    status: .error("HTTP \(code)"), primaryUsedPercent: nil, primaryResetSeconds: nil,
                    secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                    creditBalance: nil, planType: nil, lastUpdated: Date()
                )
            }
        } catch let decodingError as DecodingError {
            NSLog("[CodexUsage] Decode error for %@: %@", account.displayName, String(describing: decodingError))
            usageByAccount[account.id] = ProviderUsageData(
                status: .error("Bad response"), primaryUsedPercent: nil, primaryResetSeconds: nil,
                secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                creditBalance: nil, planType: nil, lastUpdated: Date()
            )
        } catch {
            NSLog("[CodexUsage] Network error for %@: %@", account.displayName, error.localizedDescription)
            usageByAccount[account.id] = ProviderUsageData(
                status: .error("Network error"), primaryUsedPercent: nil, primaryResetSeconds: nil,
                secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                creditBalance: nil, planType: nil, lastUpdated: Date()
            )
        }
    }

    private struct Credentials {
        let accessToken: String
        let accountId: String?
    }

    private func readCredentials(from filePath: URL) -> Credentials? {
        guard let data = try? Data(contentsOf: filePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            return nil
        }
        return Credentials(accessToken: accessToken, accountId: json["account_id"] as? String)
    }

    deinit { pollTimer?.invalidate() }
}
