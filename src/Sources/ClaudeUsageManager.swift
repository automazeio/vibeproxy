import Foundation

// MARK: - Claude API Response Model

private struct ClaudeUsageResponse: Decodable {
    let fiveHour: WindowData?
    let sevenDay: WindowData?
    let sevenDaySonnet: WindowData?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }

    struct WindowData: Decodable {
        let utilization: Double?
        let resetsAt: String? // ISO8601 timestamp

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    struct ExtraUsage: Decodable {
        let isEnabled: Bool?
        let usedCredits: Double?
        let monthlyLimit: Double?

        enum CodingKeys: String, CodingKey {
            case isEnabled = "is_enabled"
            case usedCredits = "used_credits"
            case monthlyLimit = "monthly_limit"
        }
    }
}

// MARK: - Manager

@MainActor
final class ClaudeUsageManager: ObservableObject {
    @Published private(set) var usageByAccount: [String: ProviderUsageData] = [:]

    private var pollTimer: Timer?
    private let session: URLSession
    private static let pollInterval: TimeInterval = 300 // 5 min
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    func startPolling(accounts: [AuthAccount]) {
        stopPolling()
        let active = accounts.filter { $0.type == .claude && !$0.isExpired }
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
        let active = accounts.filter { $0.type == .claude && !$0.isExpired }
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

    private func fetchUsage(for account: AuthAccount, attempt: Int = 1) async {
        guard let accessToken = readAccessToken(from: account.filePath) else {
            usageByAccount[account.id] = ProviderUsageData(
                status: .error("No credentials"), primaryUsedPercent: nil, primaryResetSeconds: nil,
                secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                creditBalance: nil, planType: nil, lastUpdated: Date()
            )
            return
        }

        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        do {
            let (data, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1

            if code == 200 {
                let parsed = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
                usageByAccount[account.id] = mapResponse(parsed)
            } else if code == 401 || code == 403 {
                usageByAccount[account.id] = ProviderUsageData(
                    status: .invalidCredentials, primaryUsedPercent: nil, primaryResetSeconds: nil,
                    secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                    creditBalance: nil, planType: nil, lastUpdated: Date()
                )
            } else if code >= 500 && attempt < 3 {
                // Retry on server errors (Anthropic 500s are transient)
                NSLog("[ClaudeUsage] HTTP %d for %@, retrying (%d/3)", code, account.displayName, attempt)
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                await fetchUsage(for: account, attempt: attempt + 1)
            } else {
                NSLog("[ClaudeUsage] HTTP %d for %@", code, account.displayName)
                usageByAccount[account.id] = ProviderUsageData(
                    status: .error("HTTP \(code)"), primaryUsedPercent: nil, primaryResetSeconds: nil,
                    secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                    creditBalance: nil, planType: nil, lastUpdated: Date()
                )
            }
        } catch let decodingError as DecodingError {
            NSLog("[ClaudeUsage] Decode error for %@: %@", account.displayName, String(describing: decodingError))
            usageByAccount[account.id] = ProviderUsageData(
                status: .error("Bad response"), primaryUsedPercent: nil, primaryResetSeconds: nil,
                secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                creditBalance: nil, planType: nil, lastUpdated: Date()
            )
        } catch {
            NSLog("[ClaudeUsage] Network error for %@: %@", account.displayName, error.localizedDescription)
            usageByAccount[account.id] = ProviderUsageData(
                status: .error("Network error"), primaryUsedPercent: nil, primaryResetSeconds: nil,
                secondaryUsedPercent: nil, secondaryResetSeconds: nil,
                creditBalance: nil, planType: nil, lastUpdated: Date()
            )
        }
    }

    private func mapResponse(_ r: ClaudeUsageResponse) -> ProviderUsageData {
        ProviderUsageData(
            status: .loaded,
            primaryUsedPercent: r.fiveHour?.utilization,
            primaryResetSeconds: secondsUntil(r.fiveHour?.resetsAt),
            secondaryUsedPercent: r.sevenDay?.utilization,
            secondaryResetSeconds: secondsUntil(r.sevenDay?.resetsAt),
            creditBalance: r.extraUsage?.usedCredits,
            planType: nil,
            lastUpdated: Date()
        )
    }

    /// Convert ISO8601 "resets_at" timestamp to seconds from now
    private func secondsUntil(_ isoString: String?) -> Int? {
        guard let str = isoString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: str) else {
            // Try without fractional seconds
            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            guard let d = basic.date(from: str) else { return nil }
            return max(0, Int(d.timeIntervalSinceNow))
        }
        return max(0, Int(date.timeIntervalSinceNow))
    }

    private func readAccessToken(from filePath: URL) -> String? {
        guard let data = try? Data(contentsOf: filePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            return nil
        }
        return accessToken
    }

    deinit { pollTimer?.invalidate() }
}
