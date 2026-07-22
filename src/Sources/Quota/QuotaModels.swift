import Foundation

enum QuotaProvider: String, CaseIterable, Hashable, Sendable {
    case anthropic = "claude"
    case openAI = "codex"

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openAI: return "OpenAI"
        }
    }

    var iconName: String {
        switch self {
        case .anthropic: return "icon-claude.png"
        case .openAI: return "icon-codex.png"
        }
    }

}

enum QuotaWindowKind: String, Sendable {
    case fiveHour
    case weekly
    case fable
}

struct QuotaWindow: Equatable, Sendable {
    let kind: QuotaWindowKind
    let remainingPercent: Double
    let resetsAt: Date?

    init(kind: QuotaWindowKind, usedPercent: Double, resetsAt: Date?) {
        self.kind = kind
        remainingPercent = 100 - min(max(usedPercent, 0), 100)
        self.resetsAt = resetsAt
    }
}

struct QuotaSnapshot: Equatable, Sendable {
    let provider: QuotaProvider
    let windows: [QuotaWindow]
    let fetchedAt: Date
    let resetCredits: CodexResetAvailability?

    init(
        provider: QuotaProvider,
        windows: [QuotaWindow],
        fetchedAt: Date,
        resetCredits: CodexResetAvailability? = nil
    ) {
        self.provider = provider
        self.windows = windows
        self.fetchedAt = fetchedAt
        self.resetCredits = resetCredits
    }

    func window(_ kind: QuotaWindowKind) -> QuotaWindow? {
        windows.first { $0.kind == kind }
    }

    var isExhausted: Bool {
        windows.contains { $0.remainingPercent <= 0 }
    }
}

struct CodexResetAvailability: Equatable, Sendable {
    let availableCount: Int
    let applicableAvailableCount: Int

    var canReset: Bool {
        applicableAvailableCount > 0
    }
}

struct CodexResetCredit: Equatable, Sendable {
    let id: String
    let title: String
    let expiresAt: Date?
}

enum CodexResetOutcome: String, Decodable, Equatable, Sendable {
    case reset
    case nothingToReset = "nothing_to_reset"
    case noCredit = "no_credit"
    case alreadyRedeemed = "already_redeemed"
}

enum QuotaFailure: String, Error, Equatable, Sendable {
    case serverUnavailable
    case managementAuthenticationFailed
    case accountUnavailable
    case providerAuthenticationFailed
    case rateLimited
    case providerUnavailable
    case invalidResponse

    var displayText: String {
        switch self {
        case .serverUnavailable: return "Server unavailable"
        case .managementAuthenticationFailed: return "Quota access unavailable"
        case .accountUnavailable: return "Account not ready"
        case .providerAuthenticationFailed: return "Sign in again"
        case .rateLimited: return "Rate limited"
        case .providerUnavailable: return "Provider unavailable"
        case .invalidResponse: return "Quota unavailable"
        }
    }
}

struct AccountQuotaState: Equatable, Sendable {
    let snapshot: QuotaSnapshot?
    let failure: QuotaFailure?
}

struct QuotaAccountReference: Sendable {
    let id: String
    let provider: QuotaProvider
}

enum QuotaDateParser {
    static func iso8601(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        return try? Date(value, strategy: .iso8601)
    }

    static func epoch(_ value: Any?) -> Date? {
        guard let number = number(value) else { return nil }
        return Date(timeIntervalSince1970: number)
    }

    static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              String(cString: number.objCType) != "c" else {
            return nil
        }
        return number.doubleValue
    }
}
